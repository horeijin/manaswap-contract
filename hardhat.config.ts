import "@nomiclabs/hardhat-waffle";
import "@nomicfoundation/hardhat-toolbox";
import { HardhatUserConfig } from "hardhat/config";

const config: HardhatUserConfig = {
  solidity: "0.8.9",
  networks: {
    hardhat: {
      gas: 10000000,
      gasPrice: 875000000,
    },
    goerli: {
      url: 'RPC노드 주소',
      accounts: ['배포에 사용할 메타마스크 개인키']
    },
  },
  etherscan: {
    apiKey: "이더스캔(메인넷)에서 발급받은 api키"
  }
};

export default config;
