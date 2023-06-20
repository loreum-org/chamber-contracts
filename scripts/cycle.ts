import { ethers } from "hardhat";
import { localhost } from "./deployments";
import { LoreumNFT, LoreumNFT__factory } from "../typechain";

async function main() {
  /*
    Cycle through all transactions
    1. Bob mints an NFT
    2. Bob Approves Alice on the NFT
    3. Bob transfers the NFT to Alice.
    4. Admin makes Alice new owner.
    5. Mint Cost updated
    6. Approval for All
  */

  // user providers / signers
  const [deployer, admin, bob, alice] = await ethers.getSigners();

  // user addresses
  const deployAdr = await deployer.getAddress();
  const adminAdr = await admin.getAddress();
  const aliceAdr = await alice.getAddress();
  const bobAdr = await bob.getAddress();

  // signer instatiated contract objects
  const adminLoreum: LoreumNFT = LoreumNFT__factory.connect(localhost.LoreumNFT, admin);
  const aliceLoreum: LoreumNFT = LoreumNFT__factory.connect(localhost.LoreumNFT, alice);
  const bobLoreum: LoreumNFT = LoreumNFT__factory.connect(localhost.LoreumNFT, bob);

  // transaction setttings
  const gasLimit = 701204;
  const gasPrice = ethers.getDefaultProvider().getGasPrice();
  const value = await adminLoreum.mintCost();

  // transaction options
  const mintTxOpts = { gasPrice, gasLimit, value };
  const txOpts = { gasPrice, gasLimit };

  //  1. Bob mints an NFT
  const bobPublicMint = await bobLoreum.publicMint(1, mintTxOpts);
  const bobPublicMintResult = await bobPublicMint.wait();
  console.log("\n******** Bob Minted NFT", bobPublicMintResult.events);

  // 2. Bob approves Alice
  const bobApprovesAlice = await bobLoreum.approve(aliceAdr, 1, txOpts);
  const bobApprovesAliceResult = await bobApprovesAlice.wait();
  console.log("\n******** Bob Approved Alice", bobApprovesAliceResult.events);

  // 3. Bob transfers NFT to Alice
  const bobTransferToAlice = await bobLoreum.transferFrom(bobAdr, aliceAdr, 1, txOpts);
  const bobTransferToAliceResult = await bobTransferToAlice.wait();
  console.log("\n******** Bob Transfered to Alice", bobTransferToAliceResult.events);

  // send back to Bob, Alice approves Bob
  const aliceApprovesBob = await aliceLoreum.approve(bobAdr, 1, txOpts);
  const aliceApprovesBobResult = await aliceApprovesBob.wait();
  console.log("\n******** Alice Approved Bob", aliceApprovesBobResult.events);

  const aliceTransferToBob = await aliceLoreum.transferFrom(aliceAdr, bobAdr, 1, txOpts);
  const aliceTransferToBobResult = await aliceTransferToBob.wait();
  console.log("\n******** Alice Transfered to Bob", aliceTransferToBobResult.events);

  // 4. Admin makes Alice new contract owner
  const aliceNewOwner = await adminLoreum.transferOwnership(aliceAdr, txOpts);
  const aliceNewOwnerResult = await aliceNewOwner.wait();
  console.log("\n******** Admin Transfers Ownership to Alice", aliceNewOwnerResult.events);

  // Make Admin owner again
  const adminNewOwner = await aliceLoreum.transferOwnership(adminAdr, txOpts);
  const adminNewOwnerResult = await adminNewOwner.wait();
  console.log("\n******** Alice Transfers Ownership back to Admin", adminNewOwnerResult.events);

  // 5. Bob makes Alice an Operator for all his NFTs
  const bobMkAliceOp = await bobLoreum.setApprovalForAll(aliceAdr, true, txOpts);
  const bobMkAliceOpResult = await bobMkAliceOp.wait();
  console.log("\n******** Bob Makes Alice operator", bobMkAliceOpResult.events);

  // Bob removes Alice as operator
  const bobRmAliceOp = await bobLoreum.setApprovalForAll(aliceAdr, false, txOpts);
  const bobRmAliceOpResult = await bobRmAliceOp.wait();
  console.log("\n******** Bob Removes Alice as operator", bobRmAliceOpResult);

  // Dump account balances
  const deployerBal = await ethers.provider.getBalance(deployAdr);
  console.log("\n******** Deployer Balance", deployAdr, ethers.utils.formatEther(deployerBal));
  const adminBal = await ethers.provider.getBalance(adminAdr);
  console.log("\n******** Admin Balance", adminAdr, ethers.utils.formatEther(adminBal));
  const bobBal = await ethers.provider.getBalance(bobAdr);
  console.log("\n******** Bob Balance", bobAdr, ethers.utils.formatEther(bobBal));
  const aliceBal = await ethers.provider.getBalance(aliceAdr);
  console.log("\n******** Alice Balance", aliceAdr, ethers.utils.formatEther(aliceBal));
}

main()
  .then(() => process.exit())
  .catch((err) => {
    console.error(err);
    return process.exit();
  });
