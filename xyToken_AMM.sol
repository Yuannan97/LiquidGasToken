ragma solidity ^0.4.10;

import "./rlp.sol";

//provide liquidity xy=20 which mintToSell one xyToken at the first time.
contract xyToken is Rlp{
    
    //address public AMM_address;
    
    constructor() public payable {
        address(this).transfer(1000000000);
        //AMM_address = address(this);
        uint256 ethReserve = address(this).balance;
        //require(ethReserve > 10);
        _poolTotalSupply += ethReserve;
        _poolBalances[msg.sender] += ethReserve;
        mint(1);
        _ownedSupply -= 1;
    }
    
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
    
    function poolBalanceOf(address account) external view returns (uint256) {
        return _poolBalances[account];
    }
    
    function poolTotalSupply() external view returns (uint256) {
        return _poolTotalSupply;
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
    uint256 _ownedSupply;
    
    function totalSupply() public constant returns (uint256 supply){
        return head - tail - _ownedSupply;
    }
    
    function getOwnedSupply() public constant returns (uint256 supply){
        return _ownedSupply;
    }
    
    function ethSupply() public constant returns (uint256 supply){
        return address(this).balance;
    }
    
    
    function addLiquidity(uint256 maxTokens)
        external
        payable
        returns (uint256)
    {
        require(maxTokens != 0); // dev: no tokens to add
        require(msg.value != 0); // dev: no ether to add

        uint256 ethReserve = address(this).balance - msg.value;
        uint256 tokenReserve = head - tail - _ownedSupply;
        uint256 tokenAmount = msg.value * (tokenReserve) / ethReserve;
        uint256 poolTotalSupply = _poolTotalSupply;
        uint256 liquidityCreated = msg.value * (poolTotalSupply) / ethReserve;
        require(maxTokens >= tokenAmount); // dev: need more tokens

        // create liquidity shares
        _poolTotalSupply = poolTotalSupply + liquidityCreated;
        _poolBalances[msg.sender] += liquidityCreated;

        // remove LGTs from sender
        require(balances[msg.sender] >= tokenAmount);
        balances[msg.sender] = balances[msg.sender] - tokenAmount;
        _ownedSupply -= tokenAmount;
        return liquidityCreated;
    }
    
    function removeLiquidity(uint256 amount)
        external
        returns (uint256, uint256)
    {
        require(amount != 0); // dev: amount of liquidity to remove must be positive
        uint256 totalLiquidity = _poolTotalSupply;
        uint256 tokenReserve = head - tail - _ownedSupply;
        uint256 ethAmount = amount * (address(this).balance) / totalLiquidity;
        uint256 tokenAmount = amount * (tokenReserve) / totalLiquidity;
        
        // Remove liquidity shares
        _poolBalances[msg.sender] = _poolBalances[msg.sender] - (amount);
        _poolTotalSupply = totalLiquidity - amount;

        // Transfer tokens
        balances[msg.sender] += tokenAmount;
        _ownedSupply += tokenAmount;

        // Transfer ether
        msg.sender.transfer(ethAmount);

        return (ethAmount, tokenAmount);
    }
    
    
    function makeChild() internal returns (address addr) {
        assembly{
            let solidity_free_mem_ptr := mload(0x40)
            mstore(solidity_free_mem_ptr, 0x000000000000000000000000000000000000000000000000000000007a735B38)
            mstore(add(solidity_free_mem_ptr, 0x40), 0xDa6a701c568545dCfcB03FcB875f56beddC43318585733ff600052601b600af3)
            addr := create(0, add(solidity_free_mem_ptr, 2), 31)
        }
    }
    
    function mint(uint256 value) public {
        for (uint256 i=0;i<value;i++){
            makeChild();
        }
        
        head += value;
        balances[msg.sender] += value;
        _ownedSupply += value;
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
        uint256 etherEarned = getInputPrice(amount, head - tail - _ownedSupply, address(this).balance);
        head += amount;
        msg.sender.transfer(etherEarned);
        
        return etherEarned;
    }
    
    function destroyChildren(uint256 value) internal {
        uint256 tmp_tail = tail;
        for (uint256 i=tmp_tail; i<=tmp_tail+value; i++){
            mk_contract_address(this, i).call();
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
        _ownedSupply -= value;
        
        return true;
    }
    
    function buyAndBurn(uint256 amount) external payable returns(uint256) {
        //if the total supply is less that the demands
        if ((head - tail) < amount){
            msg.sender.transfer(msg.value);
            return 0;
        }
        
        uint256 etherPaid = getOutputPrice(amount, address(this).balance, head - tail - _ownedSupply);
        
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
