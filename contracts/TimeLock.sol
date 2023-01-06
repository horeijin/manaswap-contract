//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract Timelock {

    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint indexed newDelay);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature,  bytes data, uint eta);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature,  bytes data, uint eta);
    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature, bytes data, uint eta);

    //딜레이
    uint public constant GRACE_PERIOD = 14 days;    //유통기한(?)
    uint public constant MINIMUM_DELAY = 5 seconds; //최소 5초
    uint public constant MAXIMUM_DELAY = 30 days;   //최대 30일

    address public admin;
    address public pendingAdmin;
    uint public delay;
    bool public admin_initialized;

    mapping (bytes32 => bool) public queuedTransactions;

    //생성자로 admin과 delay 받음
    constructor(address admin_, uint delay_) { 
        require(delay_ >= MINIMUM_DELAY, "Timelock::constructor: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::constructor: Delay must not exceed maximum delay.");

        admin = admin_; //이 컨트랙트의 Owner
        delay = delay_; //함수들이 언제 실행되는지
        admin_initialized = false;
    }

    receive() external payable { }

    //딜레이 설정
    function setDelay(uint delay_) public {
        require(msg.sender == address(this), "Timelock::setDelay: Call must come from Timelock.");
        require(delay_ >= MINIMUM_DELAY, "Timelock::setDelay: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::setDelay: Delay must not exceed maximum delay.");
        delay = delay_;

        emit NewDelay(delay);
    }

    function setPendingAdmin(address pendingAdmin_) public {
        if (admin_initialized) {
            require(msg.sender == address(this), "Timelock::setPendingAdmin: Call must come from Timelock.");
        } else {
            require(msg.sender == admin, "Timelock::setPendingAdmin: First call must come from admin.");
            admin_initialized = true;
        }
        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(pendingAdmin);
    }
    //setPendingAdmin 설정 후, 어드민 최종적으로 설정
    function acceptAdmin() public {
        require(msg.sender == pendingAdmin, "Timelock::acceptAdmin: Call must come from pendingAdmin.");
        admin = msg.sender;
        pendingAdmin = address(0);

        emit NewAdmin(admin);
    }

    //블록의 타임스탬프 구하는 함수
    function getBlockTimestamp() internal view returns (uint) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }

    //target : masterchef 컨트랙트의 주소
    //value : 전송하는 이더리움 양
    //signature : 함수 이름
    //data : 함수의 파라미터
    //eta : 타임스탬프 기준으로 얼마나 후에 실행되는지
    function queueTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public returns (bytes32) {
        require(msg.sender == admin, "Timelock::queueTransaction: Call must come from admin.");
        require(eta >= getBlockTimestamp() + delay, "Timelock::queueTransaction: Estimated execution block must satisfy delay.");

        //전달받은 함수의 파라미터들을 해시값으로 만들기
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true; //queuedTransactions 매핑에 넣음

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    //queueTransaction 함수의 데이터를 false로 돌리는 함수
    function cancelTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public {
        require(msg.sender == admin, "Timelock::cancelTransaction: Call must come from admin.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    //queueTransaction 함수 혹은 cancelTransaction 함수의 내용을 받아 최종적으로 실행
    function executeTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public payable returns (bytes memory) {
        require(msg.sender == admin, "Timelock::executeTransaction: Call must come from admin.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "Timelock::executeTransaction: Transaction hasn't been queued.");
        require(getBlockTimestamp() >= eta, "Timelock::executeTransaction: Transaction hasn't surpassed time lock.");
        require(getBlockTimestamp() <= eta + GRACE_PERIOD, "Timelock::executeTransaction: Transaction is stale."); 
        //eta기준 14일 이후의 트랜잭션은 fail
        //즉, 2주 안으로 executeTransaction을 해야 트랜잭션이 실행됨

        queuedTransactions[txHash] = false; //함수를 실행하면 다시 초기값으로 돌림

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "Timelock::executeTransaction: Transaction execution reverted.");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

}