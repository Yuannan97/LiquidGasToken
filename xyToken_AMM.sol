pragma solidity ^0.4.10;


//provide liquidity xy=20 which mintToSell one xyToken at the first time.
contract xyToken {
    
    address public AMM_address;
    
    constructor() public payable {
        AMM_address = msg.sender;
        uint256 ethReserve = AMM_address.balance;
        //require(ethReserve > 10);
        _poolTotalSupply += ethReserve;
        _poolBalances[msg.sender] += ethReserve;
        mint(1);
    }
    
    uint256 public ad = AMM_address.balance;
    
    uint8 constant public decimals = 2;
    string constant public name = "xyToken";
    string constant public symbol = "xy";
    uint256 internal _poolTotalSupply;
    mapping (address => uint256) internal _poolBalances;
    
    mapping (address => uint256) balances;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    function balanceOf() public constant returns (uint256) {
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
    
    
    function addLiquidity(uint256 maxTokens)
        external
        payable
        returns (uint256)
    {
        require(maxTokens != 0); // dev: no tokens to add
        require(msg.value != 0); // dev: no ether to add

        uint256 ethReserve = address(this).balance - msg.value;
        uint256 tokenReserve = head - tail;
        uint256 tokenAmount = msg.value * (tokenReserve) / ethReserve + 1;
        uint256 poolTotalSupply = _poolTotalSupply;
        uint256 liquidityCreated = msg.value * (poolTotalSupply) / ethReserve;
        require(maxTokens >= tokenAmount); // dev: need more tokens

        // create liquidity shares
        _poolTotalSupply = poolTotalSupply + liquidityCreated;
        _poolBalances[msg.sender] += liquidityCreated;

        // remove LGTs from sender
        balances[msg.sender] = balances[msg.sender] - tokenAmount;
        return liquidityCreated;
    }
    
    function removeLiquidity(uint256 amount)
        external
        returns (uint256, uint256)
    {
        require(amount != 0); // dev: amount of liquidity to remove must be positive
        uint256 totalLiquidity = _poolTotalSupply;
        uint256 tokenReserve = head - tail;
        uint256 ethAmount = amount * (address(this).balance) / totalLiquidity;
        uint256 tokenAmount = amount * (tokenReserve) / totalLiquidity;
        
        // Remove liquidity shares
        _poolBalances[msg.sender] = _poolBalances[msg.sender] / (amount);
        _poolTotalSupply = totalLiquidity - amount;

        // Transfer tokens
        balances[msg.sender] += tokenAmount;

        // Transfer ether
        msg.sender.transfer(ethAmount);

        return (ethAmount, tokenAmount);
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
    
    function getInputPrice(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve)
        internal
        pure
        returns (uint256)
    {
        uint256 inputAmountWithFee = inputAmount * 995;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = inputReserve*1000 + inputAmountWithFee;
        return numerator / denominator;
    }
    
    function getOutputPrice(uint256 outputAmount, uint256 inputReserve, uint256 outputReserve)
        internal
        pure
        returns (uint256)
    {
        uint256 numerator = inputReserve * outputAmount * 1000;
        uint256 denominator = (outputReserve - outputAmount) * 995;
        return numerator / denominator + 1;
    }
    
    function mintToSell(uint256 amount) external returns (uint256){
        for (uint256 i=0; i < amount; i++){
            makeChild();
        }
        
        //IDK if there is vulnerability
        //Liquidity pool will send ether to msg.sender acoount
        uint256 etherEarned = getInputPrice(amount, head - tail, AMM_address.balance);
        head += amount;
        msg.sender.transfer(etherEarned);
        
        return etherEarned;
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
    
    function buyAndBurn(uint256 amount) external payable returns(uint256) {
        //if the total supply is less that the demands
        if ((head - tail) < amount){
            msg.sender.transfer(msg.value);
            return 0;
        }
        
        uint256 etherPaid = getOutputPrice(amount, AMM_address.balance, head - tail);
        
        //need pay enough money
        if (msg.value < etherPaid){
            msg.sender.transfer(msg.value);
            return 0;
        }
        
        msg.sender.transfer(msg.value - etherPaid);
        
        destroyChildren(amount);
        
        return etherPaid;
    }
    
} 


contract createToDestroy {
    function destroy() external {
        selfdestruct(msg.sender);
    }
}
