//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "./Exchange.sol";

contract Factory{

    mapping (address => address) internal tokenToExchange;
    mapping (address => address) internal exchangeToToken;

    event NewExchange(address indexed token, address indexed exchange);

    function createExchange(address _token)public returns(address){ //페어로 생성할 ERC20 토큰의 주소를 인자로 받아 Exchange컨트랙트 배포
        require(_token != address(0));
        require(tokenToExchange[_token] == address(0)); //하나의 토큰은 하나의 페어만 만들 수 있게 (하나의 토큰 주소로 여러 페어 만들면 안됨)

        Exchange exchange = new Exchange(_token);
        tokenToExchange[_token] = address(exchange); //키 : ERC토큰의 주소, 밸류 : exchange 컨트랙트 주소
        exchangeToToken[address(exchange)] = _token;

        emit NewExchange(_token, address(exchange));
        return address(exchange);
    }

    function getExchange(address _token) public view returns(address){
        return tokenToExchange[_token]; //tokenToExchange 매핑에서 키가 _token 주소인 밸류값 리턴
    }
    function getToken(address _exchange) public view returns (address) {
        return exchangeToToken[_exchange];
    }
}