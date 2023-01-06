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
      url: 'https://ethereum-goerli-rpc.allthatnode.com/we41J8x3JX9RGVkYlmVnlKK61U4mPsnX', //all that node에서 만든 RPC노드 주소
      accounts: ['f99a14e17cfe6172f3eaefcab5bd92328150e526c9ed4e3d76d1cce73ed6665c'] //배포에 사용할 메타마스크 개인키
    },
  },
  etherscan: {
    apiKey: "R8UZH3AI7UZVF269GUTF1WKY62AJHWS23T" //이더스캔(메인넷)에서 내가 발급받은 api키
  }
};

export default config;
