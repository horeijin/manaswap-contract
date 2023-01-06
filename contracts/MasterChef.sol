// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./ManaToken.sol";

contract MasterChef is Ownable {
    struct UserInfo {
        uint256 amount; //사용자가 스테이킹한 LP토큰 예치량
        uint256 rewardDebt; // 사용자가 받을 보상에서 제외하는 값
    }
    struct PoolInfo {
        IERC20 lpToken; //LP토큰 컨트랙트 주소
        uint256 allocPoint; //이 풀에 적용되는 보상 가중치 (풀이 조성 될 때마다 증가, 풀이 늘어날수록 사용자가 받아갈 보상 거버넌스 토큰은 줄어듦)
        uint256 lastRewardBlock; //마지막 보상(거버넌스 토큰)이 갱신된 블록넘버
        uint256 accManaPerShare; //예치토큰 하나 당 보상 거버넌스 토큰 개수
    }

    ManaToken public mana; //거버넌스 토큰
    address public devaddr; //사용자가 거버넌스 토큰 민팅할 때, 일부 개수를 가져갈 개발자의 지갑계정
    uint256 public manaPerBlock; //블록 하나 생성할 떄마다 보상으로 지급할 거버넌스 토큰

    PoolInfo[] public poolInfo; //풀 정보 배열
    mapping(uint256 => mapping(address => UserInfo)) public userInfo; //LP토큰 스테이킹 하는 유저정보 저장한 매핑 
    uint256 public totalAllocPoint = 0; //각 풀마다 적용된 보상 가중치의 총 합
    uint256 public startBlock; //언제 거버넌스 토큰 민팅 시작할지(masterchef 컨트랙트가 동작 시작할지) 블록 넘버

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    //생성자
    constructor(ManaToken _mana, address _devaddr, uint256 _manaPerBlock, uint256 _startBlock) {
        mana = _mana;
        devaddr = _devaddr;
        manaPerBlock = _manaPerBlock;
        startBlock = _startBlock;
    }

    //풀이 몇 개 조성되어 있는지
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    //모든 풀 업데이트 하는 함수 (가스 소모 큼)
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    //풀 조성하는 함수 (masterchef 컨트랙트의 소유자만 호출 가능)
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock; //풀에서 마지막으로 보상 가져간 시점 계산 (처음이면 startBlock, 아니면 block.number)
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolInfo.push( //풀 정보 배열에 데이터 추가
            PoolInfo({lpToken: _lpToken, allocPoint: _allocPoint, lastRewardBlock: lastRewardBlock, accManaPerShare: 0})
        );
    }

    //어떤 풀에 설정된 allocPoint(보상 가중치) 정보 수정하는 함수
    function set(
        uint256 _pid, //조성된 어떤 풀의 id
        uint256 _allocPoint, //이 풀에 설정할 토큰 가중치
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint - prevAllocPoint + _allocPoint;
        }
    }

    //현재 블록에서 이전 보상을 받은 블록의 넘버 계산하기 위한 함수 (밑의 pendingGray함수에서 사용)
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to - _from;
    }

    //중요!
    //프론트단에서 보여줄 내가 받아야할 보상 거버넌스 토큰의 개수 계산 (실제 블록에 업데이트 되는 내용이 아니라 메모리 상에서만 업데이트)
    function pendingMana(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];         //조회할 풀의 id
        UserInfo storage user = userInfo[_pid][_user];  //나의 유저정보

        uint256 accManaPerShare = pool.accManaPerShare; //LP토큰 하나당 보상으로 받는 거버넌스 토큰 개수
        uint256 lpSupply = pool.lpToken.balanceOf(address(this)); //masterchef 컨트랙트에 스테이킹 된 LP토큰 개수

        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number); //마지막 보상 받은 후로 몇 개의 블록이 지났는지 
            uint256 manaReward = (multiplier * manaPerBlock) * pool.allocPoint / totalAllocPoint; //마나토큰풀의 보상 = 전체 보상받을 토큰 개수 * 그레이토큰 풀의 allocPoint 비율(그레이풀의 allocPoint / 전체 allocPoint)
            
            accManaPerShare = accManaPerShare + (manaReward * 1e12 / lpSupply);
        }
        return user.amount * accManaPerShare / 1e12 - user.rewardDebt; //현재 시점 받아야할 전체 보상 - 이전에 이미 받은 보상 
    }

    //중요!
    //스테이킹 풀 안의 토큰 수량이 변경 될 때마다 정보 수정하는 함수 (실제 가스 소모하여 블록에 업데이트)
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number; //만약 LP토큰이 없다면 마지막 보상 블록의 넘버만 반환
            return;
        }

        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number); //몇 개의 블록이 지났는지 계산
        uint256 manaReward = multiplier * manaPerBlock * pool.allocPoint / totalAllocPoint;
        
        mana.mint(address(this), manaReward); //거버넌스 토큰 민팅
        mana.mint(devaddr, manaReward / 10); //거버넌스 토큰 민팅 시. 개발자 지갑주소로 10%가 넘어감
        
        pool.accManaPerShare = pool.accManaPerShare + (manaReward * 1e12 / lpSupply);
        pool.lastRewardBlock = block.number;
    }

    //masterchef 컨트랙트에 LP토큰 스테이킹 하는 함수
    function deposit(uint256 _pid, uint256 _amount) public {

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        
        updatePool(_pid); //위에 만든 updatePool 함수로 풀의 정보 업데이트 (현재 구간의 accManaPerShare 계산)
        if (user.amount > 0) {
            uint256 pending = user.amount * pool.accManaPerShare / 1e12 - user.rewardDebt;
            
            if (pending > 0) {
                mana.transfer(msg.sender, pending); //토큰 컨트랙트가 유저에게 계산된 보상 거버넌스 토큰 보내줌
            }
        }
        
        if (_amount > 0) {
            pool.lpToken.transferFrom(address(msg.sender), address(this), _amount);//masterchef 컨트랙트가 유저로부터 스테이킹한 만큼 거버넌스 토큰 가져감
            user.amount = user.amount + _amount; //유저의 LP토큰 양 증가 
        }
        
        user.rewardDebt = user.amount * pool.accManaPerShare / 1e12;
        emit Deposit(msg.sender, _pid, _amount);
    }

    //masterchef 컨트랙트에 LP토큰 언스테이킹 하는 함수
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid); //현재 구간의 accGrayPerShare 계산 (예치한 토큰 개당 받아야할 거버넌스 토큰)

        uint256 pending = user.amount * pool.accManaPerShare / 1e12 - user.rewardDebt;
        if (pending > 0) {
            mana.transfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount - _amount; //유저의 LP토큰 양 감소
            pool.lpToken.transfer(address(msg.sender), _amount); //masterchef 컨트랙트가 유저에게 거버넌스 토큰 되돌려줌
        }
        user.rewardDebt = user.amount * pool.accManaPerShare /1e12;
        emit Withdraw(msg.sender, _pid, _amount);
    }

    //masterchef 컨트랙트에 거버넌스 토큰 스테이킹 하는 함수
    // function enterStaking(uint256 _amount) public {
    //     PoolInfo storage pool = poolInfo[0];
    //     UserInfo storage user = userInfo[0][msg.sender];
    //     updatePool(0);
    //     if (user.amount > 0) {
    //         uint256 pending = user.amount.mul(pool.accCakePerShare).div(1e12).sub(user.rewardDebt);
    //         if (pending > 0) {
    //             safeCakeTransfer(msg.sender, pending);
    //         }
    //     }
    //     if (_amount > 0) {
    //         pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
    //         user.amount = user.amount.add(_amount);
    //     }
    //     user.rewardDebt = user.amount.mul(pool.accCakePerShare).div(1e12);

    //     syrup.mint(msg.sender, _amount);
    //     emit Deposit(msg.sender, 0, _amount);
    // }

    //masterchef 컨트랙트에 거버넌스 토큰 언스테이킹 하는 함수
    // function leaveStaking(uint256 _amount) public {
    //     PoolInfo storage pool = poolInfo[0];
    //     UserInfo storage user = userInfo[0][msg.sender];
    //     require(user.amount >= _amount, "withdraw: not good");
    //     updatePool(0);
    //     uint256 pending = user.amount.mul(pool.accCakePerShare).div(1e12).sub(user.rewardDebt);
    //     if (pending > 0) {
    //         safeCakeTransfer(msg.sender, pending);
    //     }
    //     if (_amount > 0) {
    //         user.amount = user.amount.sub(_amount);
    //         pool.lpToken.safeTransfer(address(msg.sender), _amount);
    //     }
    //     user.rewardDebt = user.amount.mul(pool.accCakePerShare).div(1e12);

    //     syrup.burn(msg.sender, _amount);
    //     emit Withdraw(msg.sender, 0, _amount);
    // }

    //위급한 상황이라 보상은 못 주지만 예치한 토큰 양만큼이라도 돌려줌 
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.transfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    //개발자 지갑 주소 정보 갱신
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: what?");
        devaddr = _devaddr;
    }

}

