pragma solidity >= 0.4.1 < 0.7.0;

contract Ownable
{
    address private _owner;
    
    constructor () internal {
        _owner = msg.sender;
    }
    
    modifier onlyOwner()
    {
        require(isOwner());
        _;
    }
    
    function isOwner () public view returns (bool)
    {
        return msg.sender == _owner;
    }
}
