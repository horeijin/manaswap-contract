import { Exchange } from './../../uniswap-ex-contract/typechain-types/contracts/Exchange';
import { ethers } from "hardhat";
import * as Constants from "./constants";

async function main() {
  const [deployer] = await ethers.getSigners(); 
  //deployer에 들어오는 값은 hardhat config에서 작성한 메타마스크 개인키에 해당하는 지갑주소

  console.log(
    "Deploying contracts with the account:",
    deployer.address
  );
  
  //(1) 유동성 공급, 스왑과 관련된 컨트랙트 배포 -------------------------------------
  // const Factory = await ethers.getContractFactory("Factory");
  // const Contract = await Factory.deploy();

  //const ManaToken = await ethers.getContractFactory("Token");
  //const ManaTokenContract = await ManaToken.deploy("ManaToken", "MANA", 1000); //컨트랙트 생성자 매개변수 : 토큰명, 별명, 수량
  //const MoonstoneToken = await ethers.getContractFactory("Token");
  //const MoonstoneTokenContract = await MoonstoneToken.deploy("MoonstoneToken", "MST", 1000);

  //const Exchange = await ethers.getContractFactory("Exchange");
  //const ExchangeContract = await Exchange.deploy(ManaTokenContract.address); //컨트랙트 생성자 매개변수 : 토큰 컨트랙트의 주소
  //원래는 위처럼 ETH-토큰 exchange 컨트랙트를 만들어야 하지만, 나는 이미 각 토큰을 만들어버려서 각각 토큰 주소를 직접 기입
  // const ExchangeMoonstoneContract =  await Exchange.deploy("0x8D8fa8B78b828DB16529d31D554E331D39A62fD1");
  // const ExchangeManaContract = await Exchange.deploy("0xdFCE560EbA5C87F7C4F7348A8CAC9a2447844062");
  
  // console.log("Contract deployed at:", Contract.address); //factory 컨트랙트 주소
  //console.log("TokenContract deployed at:", ManaTokenContract.address);
  // console.log("ExchangeMoonstoneContract deployed at:", ExchangeMoonstoneContract.address);
  // console.log("ExchangeManaContract deployed at:", ExchangeManaContract.address);
  //------------------------------------------------------------------------------------

  //(2) 타임락 컨트랙트 배포 ------------------------------------------------------------
  // const TimelockFactory = await ethers.getContractFactory("Timelock");
  // const TimelockContract = await TimelockFactory.deploy(deployer.address, 10); //10초 뒤에 배포 실행
  
  // console.log("Timelock Contract deployed at:", TimelockContract.address);
  //-----------------------------------------------------------------------------------
  
  //(3) 스테이킹 관련된 컨트랙트 배포 ---------------------------------------------------
  // const MasterChefFactory = await ethers.getContractFactory("MasterChef");
  // const startBlock = 8226051; //goerli 테스트넷 이더스캔에서 찾은 현재 블록 넘버
  // console.log(Constants.REWARD_PER_BLOCK)
  // const MasterChefContract = await MasterChefFactory.deploy(Constants.ADDRESSES.ManaToken, Constants.ADDRESSES.Commission, Constants.REWARD_PER_BLOCK, startBlock);
  
  // console.log("MasterChef Contract deployed at:", MasterChefContract.address)

  //(4) 프론트에 풀 정보 보여주기 위한 멀티콜 컨트랙트 배포 --------------------------------
  const MulticallFactory = await ethers.getContractFactory("Multicall");
  const MulticallContract = await MulticallFactory.deploy();
  
  console.log("Multicall Contract deployed at:", MulticallContract.address);
  //------------------------------------------------------------------------------------
  
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
