pragma solidity >= 0.4.1 < 0.7.0;
//pragma experimental ABIEncoderV2;

import "./ownable.sol";

contract Main is Ownable
{
    struct Estate
    {
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
    
    //mapping (address => uint) askedForOwnership;
    mapping (uint => address) approvedOwners;
    
     /*
    Для какого объекта адрес запросил покупку
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
        string _place,
        uint16 _year,
        address _sender
    );
    
    event userApprovesNewOwner
    (
        address _to,
        uint _id,
        address _sender
    );
    
    event userAcceptsOwnership
    (
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
        emit userCreatedEstate(_description, _year, msg.sender);
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
        return address(this).balance; 
    }
    
    function getEstate(uint _id) public view returns (address, string memory, uint16, uint16, bool)
    {
        // Получение Owner и Place по id
        return (idToOwner[_id], estates[_id].description, estates[_id].year, estates[_id].area, estates[_id].living);
    }
    
    function getEstatesOfOwner () external view returns (uint32[] memory) //, string[] memory, uint16[] memory
    {
        // Вернет все запросы адреса
        uint32[] memory ids = new uint32[](addressToEstates[msg.sender]);
        //string[] memory names = new string[](addressToEstates[msg.sender]);
        //uint16[] memory dates = new uint16[](addressToEstates[msg.sender]);
        //uint16[] memory areas = new uint16[](addressToEstates[msg.sender]);
        //bool[] memory burdens = new bool[](addressToEstates[msg.sender]);
        //bool[] memory livings = new bool[](addressToEstates[msg.sender]);
        
        uint counter = 0;
        for(uint i = 0; i < estates.length ; i++)
        {
            if(idToOwner[i] == msg.sender){
                ids[counter] = uint32(i);
                //names[counter] = estates[i].description;
                //dates[counter] = estates[i].year;
                //areas[counter] = estates[i].area;
                //burdens[counter] = estates[i].burden;
                //livings[counter] = estates[i].living;
                counter++;
            }
        }
        return (ids); //, names, dates
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
        return 228;
    }
}
