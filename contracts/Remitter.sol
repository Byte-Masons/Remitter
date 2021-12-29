// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./OZ/token/ERC20/IERC20.sol";

contract Remitter {

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
  }

  //Worker ID => Information
  mapping (uint => Worker) public workerInfo;
  mapping (uint => Payment[]) public payments;
  mapping (address => uint) public employeeId;

  mapping(address => bool) public isAdmin;
  mapping(address => bool) public isSuperAdmin;

  constructor(address _superAdmin, address _currency, uint _maxSalary, uint firstPayDay) {
    isAdmin[_superAdmin] = true;
    isSuperAdmin[_superAdmin] = true;
    currency = IERC20(_currency);
    maxSalary = _maxSalary;
    startTime = firstPayDay - cycle;
  }

  function getPaid(uint workerId) external returns (bool) {
    require(msg.sender == workerInfo[workerId].wallet, "not correct wallet");
    paySalary(workerId);
    return true;
  }

  function payOut(uint workerId) external returns (bool) {
    require(isAdmin[msg.sender], "you are not authorized to remit");
    paySalary(workerId);
    return true;
  }

  function hire(uint workerId, uint salary, uint _startingCycle, address wallet) external returns (bool) {
    require(workerInfo[workerId].startingCycle == 0, "employee already exists");
    require(isAdmin[msg.sender], "caller is not admin");
    updateSalary(workerId, salary);
    updateWallet(workerId, wallet);
    workerInfo[workerId].startingCycle = _startingCycle;
    return true;
  }

  function terminate(uint workerId) external returns (bool) {
    require(isSuperAdmin[msg.sender], "caller is not admin");
    isAdmin[workerInfo[workerId].wallet] = false;
    isSuperAdmin[workerInfo[workerId].wallet] = false;
    updateSalary(workerId, 0);
    updateWallet(workerId, address(0));
    return true;
  }

  function updateCycle(uint newCycle) external returns (bool) {
    require(isSuperAdmin[msg.sender], "caller is not superAdmin");
    require(currency.balanceOf(address(this)) == 0, "payments have not all been disbursed");
    cycle = newCycle;
    return true;
  }

  function updateMaxSalary(uint newMax) external returns (bool) {
    require(isSuperAdmin[msg.sender], "caller is not superAdmin");
    maxSalary = newMax;
    return true;
  }

  function updateCurrency(address newCurrency) external returns (bool) {
    require(isSuperAdmin[msg.sender], "caller is not superAdmin");
    currency = IERC20(newCurrency);
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
      isSuperAdmin[msg.sender], "caller is not employee or super admin");

    workerInfo[workerId].wallet = newWallet;
    employeeId[newWallet] = workerId;
    return true;
  }

  function toggleAdmin(address wallet, bool status) public returns (bool) {
    require(isSuperAdmin[msg.sender], "caller is not super admin");
    isAdmin[wallet] = status;
    return true;
  }

  function paySalary(uint workerId) internal returns (bool) {
    tryAdvanceCycle();

    Worker storage worker = workerInfo[workerId];
    uint owed = worker.salary * (cycleCount - workerInfo[workerId].startingCycle - workerInfo[workerId].cyclesPaid);

    require(owed > 0, "you are not owed any payment");
    require(worker.wallet != address(0), "please update wallet");

    createPayment(workerId, owed, "salary");
    currency.transfer(worker.wallet, owed);
    return true;
  }

  function createPayment(uint workerId, uint amount, string memory description) internal returns (bool) {
    require(isAdmin[msg.sender], "caller is not admin");
    payments[workerId].push(
      Payment(
        workerInfo[workerId].wallet,
        description,
        amount,
        block.timestamp
      ));
    return true;
  }

  function tryAdvanceCycle() internal {
    uint timeAccounted = cycle * cycleCount;
    uint timeUnaccounted = block.timestamp - timeAccounted;
    if (timeUnaccounted <= cycle) {
      uint passed = timeUnaccounted / cycle;
      cycleCount += passed;
    }
  }
}
