pragma solidity >= 0.4.1 < 0.6.0;

import "./ownable.sol";

contract Main
{
    struct Estate
    {
    // Структура имущества
        string description;
        uint16 year;
        uint16 area;
        bool living;
    }
    
    Estate[] estates;
    
    
    mapping (address => uint32) addressToEstates;
    mapping (uint => address) idToOwner;
    
    /*
    Сколькими объектами владеет адрес
    Владелец по id объекта
    */
    
    mapping (uint => address) approvedOwners;
    
     /*
    Кому разрешено перевести объект
    */
    
    
    modifier ifOwner(address _sender, uint _id){
        // Проверка если пользователь является владельцем токена
        require (_sender == idToOwner[_id]);
        _;
    }
    
    
    //
    //                                          ЭВЕНТЫ
    //
    
    
    event userCreatedEstate
    (
    // Пользователь создал имущество
        uint _id
    );
    
    event userApprovesNewOwner
    (
    // Пользователь назначил нового владельца
        address _to,
        uint _id,
        address _sender
    );
    
    event userAcceptsOwnership
    (
    // Пользователь подтвердил что он владелец
        address _pastOwner,
        uint _id,
        address _sender
    );
    
    // 
    //                                              ФУНКЦИИ
    //
    
    
    function createEstate(string memory _description, uint16 _year, uint16 _area, bool _living) public
    {
        // Создание Estate
        uint id = estates.push(Estate(_description, _year, _area, _living)) - 1;
        idToOwner[id] = msg.sender;
        addressToEstates[msg.sender]++;
        emit userCreatedEstate(id);
    }
    
    function _transfer (address _from, address _to, uint _id) internal
    {
        // Трансфер другому адресу
        addressToEstates[_from]--;
        addressToEstates[_to]++;
        idToOwner[_id] = _to;
    }
    
    function pay(address _to, uint _eth) public payable
    {
    // Передать деньги адресу со своего кошелька
        require (msg.value >= _eth);
        address payable addr = address(uint160(_to));
        addr.transfer(_eth);
    }
    
    function payToContract(uint _value) public payable
    {
        // Хранить деньги на контракте
        require(msg.value >= _value);
    }
    
    function getFromContract(address adr, uint _value) internal
    {
        // Снять деньги с контракта
        address payable adrPay = address(uint160(adr));
        adrPay.transfer(_value);
    }
    
    function seeContractValue () external view returns (uint)
    {
    // Сколько денег на контракте
        return address(this).balance; 
    }
    
    function getEstate(uint _id) public view returns (address, string memory, uint16, uint16, bool)
    {
        // Получение Owner и Place по id
        return (idToOwner[_id], estates[_id].description, estates[_id].year, estates[_id].area, estates[_id].living);
    }
    
    function getEstatesOfOwner () external view returns (uint32[] memory) 
    {
        // Вернет все имущество адреса
        uint32[] memory ids = new uint32[](addressToEstates[msg.sender]);
        
        uint counter = 0;
        for(uint i = 0; i < estates.length ; i++)
        {
            if(idToOwner[i] == msg.sender){
                ids[counter] = uint32(i);
                counter++;
            }
        }
        return (ids); 
    }
    
    function approveNewOwner(address _new, uint _id) external ifOwner(msg.sender, _id) 
    {
        // Назначить нового владельца. После подтверждения помещение перейдет новому владельцу
        approvedOwners[_id] = _new;
        emit userApprovesNewOwner(_new, _id, msg.sender);
    }
    
    function acceptOwnership(uint _id) external 
    {
        // Подтверждение и принятие нового помещения
        require (msg.sender == approvedOwners[_id]);
        emit userAcceptsOwnership(idToOwner[_id], _id, msg.sender);
        _transfer(idToOwner[_id], msg.sender, _id);
    }
    
    function returnNull() external pure returns (uint)
    {
    // Тест-функция
        return 0;
    }
}
