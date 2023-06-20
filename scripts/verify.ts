import hre from "hardhat";
import * as deployments from "./deployments";

async function main() {
  const params = deployments["goerli"];
  await hre.run("verify:verify", {
    address: params.LoreumNFT,
    constructorArguments: [
      params.name,
      params.symbol,
      params.tokenUri,
      params.mintCost,
      params.royaltyFraction,
      params.maxSupply,
      params.maxMint,
      params.adminAddress,
    ],
  });
}

main()
  .then(() => process.exit())
  .catch((err) => {
    console.error(err);
    return process.exit();
  });
