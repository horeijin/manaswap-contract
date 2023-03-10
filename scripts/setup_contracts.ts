import { ethers } from "hardhat";
import { ADDRESSES } from "./constants";

async function main() {
    const [deployer] = await ethers.getSigners();

    //const TimelockFactory = await ethers.getContractFactory("Timelock");
    //const TimelockContract = await TimelockFactory.attach(ADDRESSES.Timelock);
    //await TimelockContract.setPendingAdmin(deployer.address);
    //await TimelockContract.acceptAdmin();

    const MasterChefFactory = await ethers.getContractFactory("MasterChef");
    const MasterChefContract = await MasterChefFactory.attach(ADDRESSES.Masterchef);
    await MasterChefContract.transferOwnership(ADDRESSES.Timelock); //마스터쉐프 컨트랙트의 소유권을 타임락 컨트랙트로 이양
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
