//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface IFactory{
    function getExchange(address _token) external view returns(address); //인터페이스는 무조건 external
}