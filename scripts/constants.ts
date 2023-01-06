import { ethers } from "ethers";

export const ADDRESSES = {
    //내가 하드햇으로 배포한 컨트랙트 주소들로 변경
    ManaToken: '0xdFCE560EbA5C87F7C4F7348A8CAC9a2447844062',
    MoonstoneToken: '0x8D8fa8B78b828DB16529d31D554E331D39A62fD1',
    Timelock: '0x9919bE91D8c6cC501470e11D614E4dfb8860d5a0',
    Masterchef: '0xB897855ECEDC2983072cC2832684b7C5DE22b10C',
    Commission: '0x8f7f65044E58c21DD1a91b659AbAcbc988bbce93', //커미션 받을 컨트랙트 개발자의 지갑주소
    Multicall: '0x3294284e1F5719Cd38ef9e7916c6DbA0E718368b'
}

export const REWARD_PER_BLOCK = ethers.utils.parseEther('10000'); //블록당 10000개의 보상 받음

//풀 add하기 위해 필요한 constnts
export const POOL_ADD_FUNCTION = "add"; //함수명
export const POOL_ADD_FUNCTION_SIGNATURE = "add(uint256,address,bool)"; //add함수에 들어가는 파라미터의 자료형
export const POOL_ADD_ETH_MANA_ALLOC_POINT = 100;
export const POOL_ADD_ETH_MANA_PAIR_ADDRESS = "0x9bD2d96FC5eFCfbe250f961071061c4585C8bB24"; //Exchange Mana 컨트랙트 주소

export const POOL_ADD_ETH_MOONSTONE_ALLOC_POINT = 50;
export const POOL_ADD_ETH_MOONSTONE_PAIR_ADDRESS = "0x8446194F5cea23ce86e6479dDb07f9Ec6c15e274"; //Exchange Moonstone 컨트랙트 주소