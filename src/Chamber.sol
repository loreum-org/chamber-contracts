// SPDX-License-Identifier: MIT
// Loreum Chamber v1

pragma solidity 0.8.24;

import { IChamber } from "src/interfaces/IChamber.sol";
import { IGuard } from "src/interfaces/IGuard.sol";
import { Common, IERC721, IERC20, ECDSA, SafeERC20 } from "src/Common.sol";

contract Chamber is IChamber, Common {

    /// @notice memberToken The ERC721 contract used for membership.
    address public memberToken;

    /// @notice govToken The ERC20 contract used for staking.
    address public govToken;

    /// @notice leaderboard ff members based on total delegation.
    /// @dev    Limited to top 5 leaders requiring 3 approvals
    uint256[] public leaderboard;

    /// @notice Counter to track the nonce for each proposal
    uint256 public nonce;

    /// @notice totalDelegation Tracks the amount of govToken delegated to a given NFT ID.
    /// @dev    1st element -> NFT tokenID, 2nd element -> amountDelegated.
    mapping(uint256 => uint256) public totalDelegation;

    /// @notice accountDelegation Tracks a given address's delegatation balance of govToken for a given NFT ID.
    /// @dev    1st element -> user address, 2nd element -> NFT tokenID, 3rd element -> amountDelegated.
    mapping(address => mapping(uint256 => uint256)) public accountDelegation;
    
    /// @notice proposals Mapping of the Proposals.
    /// @dev    1st element -> index, 2nd element -> Proposal struct
    mapping(uint256 => Proposal) private proposals;

    /// @inheritdoc IChamber
    function proposal(uint256 proposalId) public view returns(uint256 approvals, State state){
        return (proposals[proposalId].approvals, proposals[proposalId].state);
    }

    /// @notice vtoed Tracks which tokenIds have voted on proposals
    /// @dev    1st element -> proposalId, 2nd element -> tokenId, 3rd element-> voted boolean
    mapping(uint256 => mapping(uint256 => bool)) public voted;

    /// @notice contrcutor disables initialize function on deployment of base implementation.
    constructor() { _disableInitializers(); }
    
    /// @inheritdoc IChamber
    function initialize(address _memberToken, address _govToken) external initializer {
        require(_memberToken != address(0),"The address is zero");
        require(_govToken != address(0),"The address is zero");
        memberToken = _memberToken;
        govToken = _govToken;
    }
    
    /// @inheritdoc IChamber
    function getLeaderboard() external view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory _leaderboard = leaderboard;
        uint256[] memory _delegations = new uint256[](_leaderboard.length);
        for (uint256 i = 0; i < _leaderboard.length; i++) {
            _delegations[i] = totalDelegation[_leaderboard[i]];
        }
        return (_leaderboard, _delegations);
    }

    /// @inheritdoc IChamber
    function create(address[] memory targets, uint256[] memory values, bytes[] memory datas) external {
        if(IERC721(memberToken).balanceOf(_msgSender()) < 1) revert insufficientBalance();
        uint256[5] memory topFiveLeader;
        for (uint256 i=0; i<5; i++){
            topFiveLeader[i] = leaderboard[i];
        }
        nonce++;
        proposals[nonce] = Proposal({
            target: targets,
            value: values,
            data: datas,
            voters: topFiveLeader,
            approvals: 0,
            nonce: nonce,
            state: State.Initialized
        });
        emit ProposalCreated(nonce, targets, values, datas, topFiveLeader, nonce);
    }

    /// @inheritdoc IChamber
    function approve(uint256 proposalId, uint256 tokenId, bytes memory signature) external {
        if(_msgSender() != IERC721(memberToken).ownerOf(tokenId)) revert invalidApproval("Sender isn't NFT owner");
        if(proposals[proposalId].state != State.Initialized) revert invalidApproval("Proposal isn't Initialized");
        if(voted[proposalId][tokenId]) revert invalidApproval("TokenID already voted");

        require(verifySignature(proposalId, tokenId, signature), "Invalid signature");

        uint256[5] memory voters = proposals[proposalId].voters;
        bool onVoterList = false;

        for (uint i = 0; i < voters.length; i++) {
            if (tokenId == voters[i]) onVoterList = true;
        }

        if (!onVoterList) revert invalidApproval("TokenId not on voter list");

        voted[proposalId][tokenId] = true;
        proposals[proposalId].approvals += 1;
        emit ProposalApproved(proposalId, tokenId, proposals[proposalId].approvals);
    }

    /// @inheritdoc IChamber
    function promote(uint256 amount, uint256 tokenId) public nonReentrant {
        if(amount == 0 && tokenId == 0) revert invalidPromotion();
        
        totalDelegation[tokenId] += amount;
        accountDelegation[_msgSender()][tokenId] += amount;
        _updateLeaderboard(tokenId);
        
        SafeERC20.safeIncreaseAllowance(IERC20(govToken), address(this), amount);
        SafeERC20.safeTransferFrom(IERC20(govToken), _msgSender(), address(this), amount);
        emit Promoted(_msgSender(), amount, tokenId);
    }

    /// @inheritdoc IChamber
    function demote(uint256 amount, uint256 tokenId) public nonReentrant {
        if(amount == 0 && tokenId == 0) revert invalidDemotion();
        if(accountDelegation[_msgSender()][tokenId] < amount) revert invalidDemotion();
        
        totalDelegation[tokenId] -= amount;
        accountDelegation[_msgSender()][tokenId] -= amount;
        if (totalDelegation[tokenId]== 0){
            _removeFromLeaderboard(tokenId);
        } else {
            _updateLeaderboard(tokenId);
        }
        
        SafeERC20.safeDecreaseAllowance(IERC20(govToken), address(this), amount);
        SafeERC20.safeTransfer(IERC20(govToken), _msgSender(), amount);
        emit Demoted(_msgSender(), amount, tokenId);
    }

    /// @inheritdoc IChamber
    function execute(uint256 proposalId, uint256 tokenId, bytes memory signature) public noReentrancy{

        // TODO Implement Gas handling and Optimizations

        if( proposalId > 1 && !(_isCancellationProposal(proposalId)) ){
            require((proposals[proposalId-1].state == State.Executed || proposals[proposalId-1].state == State.Canceled), "Previous proposal must be resolved.");
        }

        require(proposals[proposalId].approvals >= 3, "Not enough approvals"); // TODO: Make quorum dynamic

        require(verifySignature(proposalId, tokenId, signature), "Invalid signature");

        bool validVoter = false;
        for (uint256 i = 0 ; i < 5; i++){
            if (tokenId == proposals[proposalId].voters[i]){
                validVoter = true;
            }
        }
        require(validVoter, "Not a voter");

        if(proposals[proposalId].state != State.Initialized) revert invalidProposalState();
       
        Proposal memory proposalData = proposals[proposalId];
        proposals[proposalId].state = State.Executed;

        address guard = getGuard();
        if (guard != address (0)){
            IGuard(guard).checkTransaction(
                proposals[proposalId].target,
                proposals[proposalId].value,
                proposals[proposalId].data,
                proposals[proposalId].voters,
                proposals[proposalId].state,
                signature,
                msg.sender,
                proposalId,
                tokenId
            );
        }
        bool finalSuccess = false;
        for (uint256 i = 0; i < proposalData.data.length; i++) {
            (bool success,) = proposalData.target[i].call{value: proposalData.value[i]}(proposalData.data[i]);
            finalSuccess = success;
            if(!success) revert executionFailed();
        }
        {
            if (guard != address(0)) {
                IGuard(guard).checkAfterExecution(constructMessageHash(proposalId, tokenId), finalSuccess);
            }
        }
        emit ProposalExecuted(proposalId);
    }

    /// @notice Checks if the proposal corresponds to a cancellation request.
    /// @param _proposalId The ID of the proposal to check.
    /// @return Whether the proposal is a cancellation request or not.
    function _isCancellationProposal(uint256 _proposalId) private view returns (bool) {
        bytes4 data = bytes4(proposals[_proposalId].data[0]);
        for (uint i = 0 ; i < 4; i++){
            if (data[i] != CANCEL_PROPOSAL_SELECTOR[i]){
                return false;
            }
        }
        return true;
    }

    //// @inheritdoc IChamber
    function cancel(uint256 proposalId) external authorized {
        require(proposals[proposalId].state == State.Initialized, "Proposal is not initialized");
        proposals[proposalId].target = new address[](1);
        proposals[proposalId].value = new uint256[](1);
        proposals[proposalId].data = new bytes[](1);

        proposals[proposalId].state = State.Canceled;

        emit ProposalCanceled(proposalId);
    }


    /// @notice _updateLeaderboard Updates the leaderboard array 
    /// @param _tokenId The ID of the NFT to update.
    function _updateLeaderboard(uint256 _tokenId) private {
        bool tokenIdExists = false;
        uint256 leaderboardLength = leaderboard.length;
        for (uint256 i = 0; i < leaderboardLength; i++) {
            if (leaderboard[i] == _tokenId) {
                tokenIdExists = true;
                break;
            }
        }
        if (tokenIdExists) {
            _bubbleSort();
        } else {
            leaderboard.push(_tokenId);
            _bubbleSort();
        }
    }

    /// @notice _bubbleSort Updates the leaderboard with bubble sort
    function _bubbleSort() private {
        bool swapped;
        uint256 leaderboardLength = leaderboard.length;
        for (uint256 i = 0; i < leaderboardLength; i++) {
            swapped = false;
            for (uint256 j = 0; j < leaderboard.length - i - 1; j++) {
                if (totalDelegation[leaderboard[j]] < totalDelegation[leaderboard[j + 1]]) {
                    (leaderboard[j], leaderboard[j + 1]) = (leaderboard[j + 1], leaderboard[j]);
                    swapped = true;
                }
            }
            if (!swapped) {
                break;
            }
        }
    }

    /// @notice _removeFromLeaderboard Removes the Token ID
    /// @param _tokenId The ID of the NFT to remove.
    function _removeFromLeaderboard(uint256 _tokenId) private {
        for (uint256 i = 0; i < leaderboard.length; i++) {
            if (leaderboard[i] == _tokenId) {
                for (uint256 j = i; j < leaderboard.length - 1; j++) {
                    leaderboard[j] = leaderboard[j + 1];
                }
                leaderboard.pop();
                break;
            }
        }
    }

    /// @inheritdoc IChamber
    function verifySignature(
        uint256 proposalId,
        uint256 tokenId,
        bytes memory signature
    ) public view returns (bool) {
        bytes32 messageHash = constructMessageHash(proposalId, tokenId);
        address signer = ECDSA.recover(messageHash, signature);
        return signer == IERC721(memberToken).ownerOf(tokenId);
    }

    /// @inheritdoc IChamber
    function domainSeparator() public view returns (bytes32) {
        uint256 chainId;
        assembly {
           chainId := chainid()
        }
        return keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, chainId, this));
    }

    function encodeData(
        address[]   memory  to,
        uint256[]   memory  value,
        bytes[]     memory  data,
        uint256[5]  memory  voters,
        uint256             approvals,
        uint256             _nonce,
        State               state,
        uint256             proposalId,
        uint256             tokenId
    )internal view returns(bytes memory){
        bytes32 txHash  = keccak256(
            abi.encode(
                to,
                value,
                data,
                voters,
                approvals,
                _nonce,
                state,
                proposalId,
                tokenId
            )
        );
        return abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator(), txHash);
    }

    /// @inheritdoc IChamber
    function constructMessageHash(
        uint256 proposalId, 
        uint256 tokenId
    ) public view returns (bytes32) {
        return keccak256(
            encodeData(
                proposals[proposalId].target,
                proposals[proposalId].value,
                proposals[proposalId].data,
                proposals[proposalId].voters,
                proposals[proposalId].approvals,
                proposals[proposalId].nonce,
                proposals[proposalId].state,
                proposalId,
                tokenId
            )
        );
    }

    fallback() external payable {
        if (msg.value > 0) emit ReceivedEther(_msgSender(), msg.value);
    }

    receive() external payable {
        if (msg.value > 0) emit ReceivedFallback(msg.sender, msg.value);
    }
}