import { ethers } from "hardhat";
import { Interface } from '@ethersproject/abi'
import { arrayify } from "ethers/lib/utils";

import * as MasterChefConstants from "./constants";
import { ADDRESSES } from "./constants";
import { MasterChef__factory } from "../typechain-types";

async function main() {

    const TimelockFactory = await ethers.getContractFactory("Timelock");
    const TimelockContract = await TimelockFactory.attach(ADDRESSES.Timelock);

    const allocPoint = MasterChefConstants.POOL_ADD_ETH_MANA_ALLOC_POINT;
    const lpAddress = MasterChefConstants.POOL_ADD_ETH_MANA_PAIR_ADDRESS;
    //const allocPoint = MasterChefConstants.POOL_ADD_ETH_GUSD_ALLOC_POINT;
    //const lpAddress = MasterChefConstants.POOL_ADD_ETH_GUSD_PAIR_ADDRESS;

    const itf = new Interface(MasterChef__factory.abi);
    const encodedData = itf.encodeFunctionData(MasterChefConstants.POOL_ADD_FUNCTION, [allocPoint, lpAddress, false]) //constants.ts에서 POOL_ADD_FUNCTION_SIGNATURE에 해당하는 부분

    /*
        target: MasterChef Address
        value: 0
        function signature: add(uint256,address,bool)
        data(function parameter): '0x' + callData.substring(10)
        eta: timestamp
    */
    const targetAddress = ADDRESSES.Masterchef;
    const functionSignature = MasterChefConstants.POOL_ADD_FUNCTION_SIGNATURE;
    const callData = arrayify('0x' + encodedData.substring(10)); //(0x + 위에서 만든 encodedData의 인덱스10~끝까지 문자열)은 string이므로 arrayify로 바이트코드로 변환
    // console.log(encodedData)
    
    //현재 시간(단위 ms)를 1000으로 나누어 second로 변환하고 floor로 소수점 아래 그냥 버림
    let timestampSecond = Math.floor(+ new Date() / 1000); //queueTransaction 할 때는 이 타임스탬프 사용
    //그런데 이렇게 현재 함수 실행하는 시간으로 timestamp를 실행하면 queueTransaction할 때랑 executeTransaction할 때랑 다른 시간이 들어가버림
    //executeTransaction를 하려면 queueTransaction할 때의 타임스탬프가 그대로 들어가야 함
    console.log(timestampSecond);

    //let timestampSecond = 1672400997; //위에서 콘솔로그로 찍은 타임스탬프값으로 executeTransaction 실행
    const eta = timestampSecond + 11; //현재 시간보다 11초 후에 execute 되어야 함
    
    await TimelockContract.queueTransaction(targetAddress, 0, functionSignature, callData, eta); //타임락 컨트랙트가 트랜잭션 큐에 넣는 함수 불러서 사용
    await TimelockContract.executeTransaction(targetAddress, 0, functionSignature, callData, eta); //큐에 넣어진 트랜잭션 실행하는 함수
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
