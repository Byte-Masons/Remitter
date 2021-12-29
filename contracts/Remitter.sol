// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./OZ/token/ERC20/IERC20.sol";
import "./OZ/security/ReentrancyGuard.sol";
import "./OZ/token/ERC20/utils/SafeERC20.sol";

// Written by Justin Bebis, secured by Goober

contract Remitter is ReentrancyGuard {
  using SafeERC20 for IERC20;

  address superAdmin;

  uint cycle = 15 days;
  uint cycleCount;
  uint startTime;

  uint totalPayroll;
  uint maxSalary;
  IERC20 currency;

  struct Payment {
    address to;
    string description;
    uint amount;
    uint time;
  }

  struct Worker {
    uint salary;
    uint startingCycle;
    uint cyclesPaid;
    address wallet;
    bool adminCanRemit;
  }

  //Worker ID => Information
  mapping (uint => Worker) public workerInfo;
  mapping (uint => Payment[]) public payments;
  mapping (address => uint) public employeeId;

  mapping(address => bool) public isAdmin;

  event PaymentCreated(
    address indexed currency,
    uint workerId,
    uint amount,
    string indexed description,
    uint timstamp
  );

  constructor(address _superAdmin, address _currency, uint _maxSalary, uint firstPayDay) {
    isAdmin[_superAdmin] = true;
    superAdmin = _superAdmin;
    currency = IERC20(_currency);
    maxSalary = _maxSalary;
    startTime = firstPayDay - cycle;
  }

  function getPaid(uint workerId) external returns (bool) {
    require(msg.sender == workerInfo[workerId].wallet, "not correct wallet");
    _pay(workerId);
    return true;
  }

  function payOut(uint workerId) external returns (bool) {
    require(isAdmin[msg.sender], "you are not authorized to remit");
    require(workerInfo[workerId].adminCanRemit, "push payments not authorized");
    _pay(workerId);
    return true;
  }

  function hire(uint workerId, uint salary, uint _startingCycle, address wallet, bool _adminCanRemit) external returns (bool) {
    require(workerInfo[workerId].startingCycle == 0, "employee already exists");
    require(isAdmin[msg.sender], "caller is not admin");
    updateSalary(workerId, salary);
    updateWallet(workerId, wallet);
    workerInfo[workerId].startingCycle = _startingCycle;
    workerInfo[workerId].adminCanRemit = _adminCanRemit;
    return true;
  }

  function terminate(uint workerId) external returns (bool) {
    require(msg.sender == superAdmin, "caller is not super admin");
    isAdmin[workerInfo[workerId].wallet] = false;
    _pay(workerId);
    updateSalary(workerId, 0);
    updateWallet(workerId, address(0));
    return true;
  }

  function updateCycle(uint newCycle) external returns (bool) {
    require(msg.sender == superAdmin, "caller is not super admin");
    cycle = newCycle;
    return true;
  }

  function updateMaxSalary(uint newMax) external returns (bool) {
    require(msg.sender == superAdmin, "caller is not super admin");
    maxSalary = newMax;
    return true;
  }

  function updateCurrency(address newCurrency) external returns (bool) {
    require(msg.sender == superAdmin, "caller is not super admin");
    require(newCurrency != address(currency), "please enter a different currency");
    currency = IERC20(newCurrency);
    return true;
  }

  function toggleAdmin(address wallet, bool status) external returns (bool) {
    require(msg.sender == superAdmin, "caller is not super admin");
    isAdmin[wallet] = status;
    return true;
  }

  function changeSuperAdmin(address newSuper) external returns (bool) {
    require(msg.sender == superAdmin, "not super admin");
    superAdmin = newSuper;
    return true;
  }

  function updateSalary(uint workerId, uint newSalary) public returns (bool) {
    require(isAdmin[msg.sender], "caller is not admin");
    require(newSalary <= maxSalary, "salary input too high");
    totalPayroll -= workerInfo[workerId].salary;
    workerInfo[workerId].salary = newSalary;
    totalPayroll += newSalary;
    return true;
  }

  function updateWallet(uint workerId, address newWallet) public returns (bool) {
    require(msg.sender == workerInfo[workerId].wallet ||
      msg.sender == superAdmin, "caller is not super admin");

    workerInfo[workerId].wallet = newWallet;
    employeeId[newWallet] = workerId;
    return true;
  }

  function _pay(uint workerId) internal nonReentrant returns (bool) {
    _tryAdvanceCycle();

    Worker storage worker = workerInfo[workerId];
    uint owed = worker.salary * (cycleCount - worker.startingCycle - worker.cyclesPaid);

    require(owed > 0, "you are not owed any payment");
    require(worker.wallet != address(0), "please update wallet");

    _createPayment(workerId, owed, "salary");
    workerInfo[workerId].cyclesPaid = worker.startingCycle + cycleCount;
    currency.safeTransfer(worker.wallet, owed);

    if(worker.salary > maxSalary) {
      worker.salary = maxSalary;
    }
    return true;
  }

  function _createPayment(uint workerId, uint amount, string memory description) internal returns (bool) {
    require(isAdmin[msg.sender], "caller is not admin");
    payments[workerId].push(
      Payment(
        workerInfo[workerId].wallet,
        description,
        amount,
        block.timestamp
      ));
    emit PaymentCreated(address(currency), workerId, amount, description, block.timestamp);
    return true;
  }

  function _tryAdvanceCycle() internal {
    uint timeAccounted = cycle * cycleCount + startTime;
    uint timeUnaccounted = block.timestamp - timeAccounted;
    if (timeUnaccounted >= cycle) {
      uint passed = timeUnaccounted / cycle;
      cycleCount += passed;
    }
  }
}
