import { BigNumber } from "ethers";
import hardhat, { ethers } from "hardhat";
import * as deployments from "./deployments";

type DeploymentParams = {
  membershipToken: string,
  stakingToken: string,
  quorum: number,
  leaders: number
};

async function main() {
  const network: String = (await ethers.provider.getNetwork()).name;
  console.log("Network:", "\t\t", network);
  switch (network) {
    case "unknown":
      return deployLocalhost();
  }
}

async function deployLocalhost() {
    
    const Chamber = await ethers.getContractFactory("Chamber");
    const chamber = await Chamber.deploy(
      deployments.localhost.erc721.address,
      deployments.localhost.erc20.address,
      deployments.localhost.chamber.quorum,
      deployments.localhost.chamber.leaders
    );

    await chamber.deployed();
    console.log("Chamber Contract:", "\t", chamber.address);
    console.log("Membership Token:", "\t", deployments.localhost.erc721.address);
    console.log("Staking Token:", "\t\t", deployments.localhost.erc20.address);
    console.log("Quorum:", "\t\t", deployments.localhost.chamber.quorum);
    console.log("Leaders:", "\t\t", deployments.localhost.chamber.leaders);
}

main()
  .then(() => process.exit())
  .catch((err) => {
    console.error(err);
    return process.exit();
  });
