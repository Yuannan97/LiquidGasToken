pragma solidity ^0.4.10;


contract xyToken {

    uint8 constant public decimals = 2;
    string constant public name = "xyToken";
    string constant public symbol = "xy";
    
    mapping(address => uint256) balances;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    function balanceOf() public constant returns (uint256 balance) {
        return balances[msg.sender];
    }
    
    function internalTransfer(address from, address to, uint256 value) internal returns (bool success) {
        if (value <= balances[from]) {
            balances[from] -= value;
            balances[to] += value;
            Transfer(from, to, value);
            return true;
        } else {
            return false;
        }
    }

    // Spec: Send `value` amount of tokens to address `to`
    function transfer(address to, uint256 value) public returns (bool success) {
        address from = msg.sender;
        return internalTransfer(from, to, value);
    }
    
    ////////////////
    //realization//
    ///////////////
    uint256 head;
    uint256 tail;
    address[] contractAddress;
    
    function totalSupply() public constant returns (uint256 supply){
        return head - tail;
    }
    
    function makeChild() internal returns (address addr) {
        address newContract = new createToDestroy();
        contractAddress.push(newContract);
        
        return newContract;
    }
    
    function mint(uint256 value) public {
        for (uint256 i=0;i<value;i++){
            makeChild();
        }
        
        head += value;
        balances[msg.sender] += value;
    }
    
    
    function destroyChildren(uint256 value) internal {
        uint256 tmp_tail = tail;
        for (uint256 i=tmp_tail; i<=tmp_tail+value; i++){
            address(contractAddress[i]).call.value(0 wei);
        }
        tail = tmp_tail + value;
    }
    
    function burn(uint256 value) public returns (bool success) {
        uint256 account_balance = balances[msg.sender];
        if (value > account_balance) {
            return false;
        }
        
        destroyChildren(value);
        
        balances[msg.sender] = account_balance - value;
        
        return true;
    }
    
    
    
} 

// it is a vulnerable way and no one would do that
// this is just for study
contract createToDestroy {
    function destroy() external {
        selfdestruct(msg.sender);
    }
}
