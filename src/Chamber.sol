// SPDX-License-Identifier: MIT
// Loreum Chamber v1

pragma solidity 0.8.19;

import { IChamber } from "./interfaces/IChamber.sol";
import { IGuard } from "./interfaces/IGuard.sol";
import { Common, IERC721, IERC20, ECDSA, SafeERC20 } from "./Common.sol";

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
    function createProposal(address[] memory _target, uint256[] memory _value, bytes[] memory _data) external {
        if(IERC721(memberToken).balanceOf(_msgSender()) < 1) revert insufficientBalance();
        uint256[5] memory topFiveLeader;
        for (uint256 i=0; i<5; i++){
            topFiveLeader[i] = leaderboard[i];
        }
        nonce++;
        proposals[nonce] = Proposal({
            target: _target,
            value: _value,
            data: _data,
            voters: topFiveLeader,
            approvals: 0,
            nonce: nonce,
            state: State.Initialized
        });
        emit ProposalCreated(nonce, _target, _value, _data, topFiveLeader, nonce);
    }

    /// @inheritdoc IChamber
    function approveProposal(uint256 _proposalId, uint256 _tokenId, bytes memory _signature) external {
        if(_msgSender() != IERC721(memberToken).ownerOf(_tokenId)) revert invalidApproval("Sender isn't NFT owner");
        if(proposals[_proposalId].state != State.Initialized) revert invalidApproval("Proposal isn't Initialized");
        if(voted[_proposalId][_tokenId]) revert invalidApproval("TokenID already voted");

        require(verifySignature(_proposalId, _tokenId, _signature), "Invalid signature");

        uint256[5] memory voters = proposals[_proposalId].voters;
        bool onVoterList = false;

        for (uint i = 0; i < voters.length; i++) {
            if (_tokenId == voters[i]) onVoterList = true;
        }

        if (!onVoterList) revert invalidApproval("TokenId not on voter list");

        voted[_proposalId][_tokenId] = true;
        proposals[_proposalId].approvals += 1;
        emit ProposalApproved(_proposalId, _tokenId, proposals[_proposalId].approvals);
    }

    /// @inheritdoc IChamber
    function promote(uint256 _amt, uint256 _tokenId) public nonReentrant {
        if(_amt == 0 && _tokenId == 0) revert invalidPromotion();
        
        totalDelegation[_tokenId] += _amt;
        accountDelegation[_msgSender()][_tokenId] += _amt;
        _updateLeaderboard(_tokenId);
        
        SafeERC20.safeTransferFrom(IERC20(govToken), _msgSender(), address(this), _amt);
        emit Promoted(_msgSender(), _amt, _tokenId);
    }

    /// @inheritdoc IChamber
    function demote(uint256 _amt, uint256 _tokenId) public nonReentrant {
        if(_amt == 0 && _tokenId == 0) revert invalidDemotion();
        if(accountDelegation[_msgSender()][_tokenId] < _amt) revert invalidDemotion();
        
        totalDelegation[_tokenId] -= _amt;
        accountDelegation[_msgSender()][_tokenId] -= _amt;
        if (totalDelegation[_tokenId]== 0){
            _removeFromLeaderboard(_tokenId);
        }else{
            _updateLeaderboard(_tokenId);
        }
        
        SafeERC20.safeTransfer(IERC20(govToken), _msgSender(), _amt);
        emit Demoted(_msgSender(), _amt, _tokenId);
    }

    /// @inheritdoc IChamber
    function executeProposal(uint256 _proposalId, uint256 _tokenId, bytes memory _signature) public noReentrancy{

        // TODO Implement Gas handling and Optimizations

        if( _proposalId > 1 && !(_isCancellationProposal(_proposalId)) ){
            require((proposals[_proposalId-1].state == State.Executed || proposals[_proposalId-1].state == State.Canceled), "Previous proposal must be resolved.");
        }

        require(proposals[_proposalId].approvals >= 3, "Not enough approvals"); // TODO: Make quorum dynamic

        require(verifySignature(_proposalId, _tokenId, _signature), "Invalid signature");

        bool validVoter = false;
        for (uint256 i = 0 ; i < 5; i++){
            if (_tokenId == proposals[_proposalId].voters[i]){
                validVoter = true;
            }
        }
        require(validVoter, "Not a voter");

        if(proposals[_proposalId].state != State.Initialized) revert invalidProposalState();
       
        Proposal memory proposalData = proposals[_proposalId];
        proposals[_proposalId].state = State.Executed;

        address guard = getGuard();
        if (guard != address (0)){
            IGuard(guard).checkTransaction(
                proposals[_proposalId].target,
                proposals[_proposalId].value,
                proposals[_proposalId].data,
                proposals[_proposalId].voters,
                proposals[_proposalId].state,
                _signature,
                msg.sender,
                _proposalId,
                _tokenId
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
                IGuard(guard).checkAfterExecution(constructMessageHash(_proposalId, _tokenId), finalSuccess);
            }
        }
        emit ProposalExecuted(_proposalId);
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
    function cancelProposal(uint256 _proposalId) external authorized {
        require(proposals[_proposalId].state == State.Initialized, "Proposal is not initialized");
        proposals[_proposalId].target = new address[](1);
        proposals[_proposalId].value = new uint256[](1);
        proposals[_proposalId].data = new bytes[](1);

        proposals[_proposalId].state = State.Canceled;

        emit ProposalCanceled(_proposalId);
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
        uint256 _proposalId,
        uint256 _tokenId,
        bytes memory _signature
    ) public view returns (bool) {
        bytes32 messageHash = constructMessageHash(_proposalId, _tokenId);
        address signer = ECDSA.recover(messageHash, _signature);
        return signer == IERC721(memberToken).ownerOf(_tokenId);
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
        address[] memory _to,
        uint256[] memory _value,
        bytes[]   memory _data,
        uint256[5]  memory _voters,
        uint256            _approvals,
        uint256          _nonce,
        State            _state,
        uint256          _proposalId,
        uint256            _tokenId
    )internal view returns(bytes memory){
        bytes32 txHash  = keccak256(
            abi.encode(
                _to,
                _value,
                _data,
                _voters,
                _approvals,
                _nonce,
                _state,
                _proposalId,
                _tokenId
            )
        );
        return abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator(), txHash);
    }

    /// @inheritdoc IChamber
    function constructMessageHash(
        uint256 _proposalId, 
        uint256 _tokenId
    ) public view returns (bytes32) {
        return keccak256(
            encodeData(
                proposals[_proposalId].target,
                proposals[_proposalId].value,
                proposals[_proposalId].data,
                proposals[_proposalId].voters,
                proposals[_proposalId].approvals,
                proposals[_proposalId].nonce,
                proposals[_proposalId].state,
                _proposalId,
                _tokenId
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