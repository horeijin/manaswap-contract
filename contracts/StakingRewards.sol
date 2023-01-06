// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Stakingrewards is Ownable{
    IERC20 public stakingToken; //스테이킹 풀에 스테이킹할 토큰
    IERC20 public rewardsToken; //보상으로 줄 토큰
    //스테이킹 토큰과 보상 토큰은 같을 수도 다를 수도 있음

    // 초당 리워드의 개수
    uint256 public rewardRate = 0;

    // 스테이킹 기간
    uint256 public rewardsDuration = 365 days;

    // 스테이킹이 끝나는 시간
    uint256 public periodFinish = 0;

    //마지막 업데이트 시간(스테이킹 수량(totalStakingAmountAtTime) 혹은 설정 변경 시점)
    uint256 public lastUpdateTime;

    // 각 구간별 토큰당 리워드의 누적값(전체 구간의 리워드) 스테이킹 풀에서 전체 보유량이 바뀔 때의 누적보샹량
    uint256 public rewardPerTokenStored;

    // 이미 계산된 유저의 리워드 총합
    mapping(address => uint256) public userRewardPerTokenPaid;

    // 출금 가능한 누적된 리워드의 총합(누적 보상)
    mapping(address => uint256) public rewards;

    //전체 스테이킹된 토큰 개수
    uint256 private _totalSupply;

    // 유저의 스테이킹 개수
    mapping(address => uint256) private _balances;

    //생성자
    constructor(address _rewardsToken, address _stakingToken) {
        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);
    }

    //----------------- 함수 ----------------------

    /*
        (1) rewardPerToken:
        구간에서 스테이킹 토큰 하나당 보상 토큰의 개수
        예: 스테이킹 풀의 토큰 총량이 100개, 
            스테이킹한 구간에 대한 보상이 5개,
            스테이킹 토큰당 보상 리워드는 5/100개

        (2) rewardPerTokenStored: 구간 변화에 따른 rewardPerToken의 누적값

        이 두 개의 값을 이용해 보상을 업데이트하는 기능에 사용
    */

    //누적 보상 계산했던 시점
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }
    
    //보상받아야 할 토큰 계산
    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {          //처음 스테이킹 하는 경우
            return rewardPerTokenStored;  //누적된 보상 토큰량 = 0
        }
        //스테이킹 처음이 아닌 경우, 기존 누적된 보상토큰 + 새로운 보상토큰
        return
            rewardPerTokenStored + //누적된 보상량 +
            (rewardRate            //이자율
            * (lastTimeRewardApplicable() - lastUpdateTime) * 1e18) //구간변화량
            /_totalSupply;         //스테이킹 풀의 총 토큰량 
    }

    //보상 업데이트하는 수정자 -> 스테이킹 풀의 총량이 변하는 함수들에 필수적으로 적용
    //왜? 스테이킹의 보상은 스테이킹 풀 안의 토큰 총량이 변할 때마다 계산하고, 스테이킹 기간 끝날 떄 한꺼번에 주므로
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken(); //지금까지 누적된 보상 토큰량
        lastUpdateTime = lastTimeRewardApplicable(); //누적 보상량 계산했던 시점
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    //----------------- 본격적인 기능 구현 ----------------------

    //전체 스테이킹된 토큰의 개수
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    //유저가 스테이킹한 토큰의 개수
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    //스테이킹
    function stake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        _totalSupply += amount;           //스테이킹 하면 전체 스테이킹 풀양 증가
        _balances[msg.sender] += amount;  //스테이킹 한 계정의 스테이킹 예치량 증가
        stakingToken.transferFrom(msg.sender, address(this), amount); //스테이킹 토큰 주소가 스테이킹하는 계정의 토큰을 가져옴
    }

    //언스테이킹
    function withdraw(uint256 amount) public updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply -= amount;  //스테이킹 하면 전체 스테이킹 풀양 감소
        _balances[msg.sender] -= amount; ///스테이킹 한 계정의 스테이킹 예치량 감소
        stakingToken.transfer(msg.sender, amount); //스테이킹 토큰 주소가 언스테이킹하는 계정으로 토큰을 보내줌
    }

    //스테이킹 보상 전달
    function getReward() public updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender]; //rewards 매핑에서 msg.sender가 키값안 밸류값인 보상 찾음
        if (reward > 0) {
            rewards[msg.sender] = 0; //매핑에서 키가 msg.sender인 밸류값을 0으로 갱신
            rewardsToken.transfer(msg.sender, reward); //보상토큰 주소가 언트테이킹한 계정으로 보상 보내줌
        }
    }

    function notifyRewardAmount(uint256 reward) external onlyOwner updateReward(address(0)){
        // 처음 비율을 설정하거나 스테이킹 기간이 끝난 경우 (periodFinish의 초기값은 0)
        if (block.timestamp >= periodFinish) {
            //reward가 31536000 (60*60*24*365)라면 1초당 1개의 리워드 코인이 분배
            rewardRate = reward / rewardsDuration;
        } else {
            //스테이킹 종료 전 추가로 리워드를 배정하는 경우
            uint256 remaning = periodFinish - block.timestamp;
            uint256 leftover = remaning * rewardRate;
            rewardRate = reward + leftover / rewardsDuration;
        }

        uint256 balance = rewardsToken.balanceOf(address(this));
        require(rewardRate <= balance / rewardsDuration, "Provided reward too high");
        //보상으로 줄 토큰이 풀 안에 있는 토큰 양보다 크면 못 줌 (스테이킹 토큰과 보상 토큰이 동일한 토큰일 경우의 계산) 

        lastUpdateTime = block.timestamp;

        // 스테이킹 종료 시간 업데이트, 현재 시간에서 1년을 연장
        periodFinish = block.timestamp + rewardsDuration;
    }

    // 지금까지 나의 총 보상을 조회
    function earned(address account) public view returns (uint256) {
        // _balances[account] * rewardPerToken() -> account의 전체 구간의 보상
        // _balances[account] * userRewardPerTokenPaid[account] -> 이전 시점에 계산했던 누적 보상량
        return
            (_balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account]))/1e18 
            + rewards[account]; //account가 출금 가능한 누적된 보상
            
    }

}