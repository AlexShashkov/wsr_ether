pragma solidity >= 0.4.1 < 0.7.0;
//pragma experimental ABIEncoderV2;

import "./estate.sol";

contract Deposit is Main
{
    struct Advertisment
    {
        // Структура рекламы
        uint id;
        uint value;
        uint32 prop_lifetime;
        uint32 lifetime;
        address owner;
    }
    
    struct Buyer
    {
        uint adId;
        uint value;
        uint8 state;
        address buyer;
    }
    
    // state: 0: отказано, 1: неизвестно, 2: деньги возвращены, 3: купил
    
    Advertisment[] ads;
    Buyer[] buyers;
    
    mapping (address => uint32) addressToAds;
    mapping (address => uint32) addressToBuyers;
    mapping (uint => address) idHolders;
    
    
     //
    //                                          ЭВЕНТЫ
    //
    
    
    event createAdvertisment
    (
        // Создание рекламы
        uint _id,
        uint _value,
        uint32 prop_lifetime,
        uint _lifetime,
        address _sender
    );
    
    event cancellAdvertisment
    (
        // Отозвание рекламы
        uint _id,
        address _sender
    );
    
    event userAskedPurchase
    (
        // Запрос на покупку
        uint _id,
        uint _value,
        address _sender
    );
    
    event ownerDeclinedUser
    (
        // Отказ в покупке
        address _to, 
        uint _id,
        address _sender
    );
    
    event ownerAcceptsUser
    (
        // Покупка
        address _to,
        uint _id,
        address _sender
    );
    
    event ownerReturnsDeposit
    (
        // Залог возвращен
        address _to,
        uint _id,
        address _sender
    );
    
    event depositFails
    (
        // Залог не возвращен
        address _to,
        uint _id,
        address _sender
    );
    
    
    // 
    //                                              ФУНКЦИИ
    //
    
    
    function createAd(uint _id, uint _value, uint32 _propLifetime, uint _lifetime) external ifOwner(msg.sender, _id)
    {
        // Создать объявление о продаже
        uint32 stamp = uint32(now + _lifetime * 1 days);
        ads.push(Advertisment(_id, _value, _propLifetime, stamp, msg.sender));
        addressToAds[msg.sender]++;
        emit createAdvertisment(_id, _value, _propLifetime, stamp, msg.sender);
    }
    
    function cancellAd(uint _id) external ifOwner(msg.sender, ads[_id].id)
    {
        // Отменить объявление о продаже
        require(ads[_id].lifetime > now);
        ads[_id].lifetime = uint32(now);
        for(uint i = 0; i<buyers.length; i++)
        {
            // В цикле по всем объявлениям проверяем id. Если id равен _id объявления и статус покупателя равен "неизвестно", а также он не является подтвержденным, то возвращаем деньги
            if (buyers[i].adId == _id && buyers[i].state == 1)
            {
                getFromContract(buyers[i].buyer, buyers[i].value);
                Buyer storage buy = buyers[i];
                buy.state = 2;
            }
        }
        emit cancellAdvertisment(_id, msg.sender);
    }
    
    function requestDeposit(uint _id) external payable
    {
        // Запросить залог и перевести деньги на хранилище
        require(ads[_id].lifetime > now);
        require(msg.value >= ads[_id].value);
        payToContract(ads[_id].value);
        //askedForOwnership[msg.sender] = _id;
        //askedForOwnershipSize++;
        buyers.push(Buyer(_id, ads[_id].value, 1, msg.sender));
        addressToBuyers[msg.sender]++;
        emit userAskedPurchase(_id, msg.value, msg.sender);
    }
    
    function declineDeposit(address _to, uint _id) external
    {
        // отказать в залоге
        require(ads[_id].lifetime > now);
        require (_to == msg.sender || msg.sender == idToOwner[ads[_id].id]);
        for(uint i = 0; i<buyers.length; i++)
        {
            if(buyers[i].buyer == _to && buyers[i].adId == _id && buyers[i].state == 1)
            {
                getFromContract(buyers[i].buyer, buyers[i].value);
                Buyer storage buy = buyers[i];
                buy.state = 0;
            }
        }
        emit ownerDeclinedUser(_to, _id, msg.sender);
    }
    
    function makeOwner(address _to, uint _id) external ifOwner(msg.sender, ads[_id].id)
    {
        // Подтвердить владельца и снять деньги. Деньги также переводятся остальным людям которые запросили покупку ДАННОГО id и имеют статус 1
        require(ads[_id].lifetime > now);
        Advertisment memory ad = ads[_id];
        //_transfer(msg.sender, _to, ad.id);
        for(uint i = 0; i<buyers.length; i++)
        {
            if(buyers[i].buyer != _to)
            {
                if(buyers[i].adId == _id && buyers[i].state == 1)
                {
                    Buyer storage buy = buyers[i];
                    buy.state = 2;
                    getFromContract(buyers[i].buyer, ad.value);
                }
            }
            else
            {
                Buyer storage buy = buyers[i];
                buy.state = 3;
            }
        }
        getFromContract(msg.sender, ad.value);
        ads[_id].lifetime = uint32(now);
        idHolders[_id] = _to;
        emit ownerAcceptsUser(_to, _id, msg.sender);
    }
    
    function depositPayBack(uint _id) external payable ifOwner(msg.sender, ads[_id].id)
    {
        // Вернуть залог
        require (ads[_id].prop_lifetime > now);
        require (msg.value >= ads[_id].value);
        require (idHolders[_id] != address(0));
        pay(idHolders[_id], msg.value);
        emit ownerReturnsDeposit (idHolders[_id], _id, msg.sender);
        idHolders[_id] = address(0); 
    }
    
    
    function checkLifeTime(uint _id) external  
    {
        // Проверить лайфтайм объявления
        // TODO: запустить в таймер
        if(ads[_id].lifetime <= now)
        {
            for(uint i = 0; i<buyers.length; i++)
            {
                if (buyers[i].adId == _id && buyers[i].state == 1)
                {
                    Buyer storage buy = buyers[i];
                    buy.state = 2;
                    getFromContract(buyers[i].buyer, buyers[i].value);
                }
            }
        }   
    }
    
    function checkProplifetime(uint _id) external  
    {
        // Проверка не истек ли срок выплаты залога. Если истек - передать имущество залогодателю
        // TODO: ЗАПУСТИТЬ В ТАЙМЕР
        if (ads[_id].prop_lifetime <= now)
        {
            if (idHolders[_id] != address(0))
            {
                _transfer(ads[_id].owner, idHolders[_id], _id);
                emit depositFails(idHolders[_id], _id, msg.sender);
                idHolders[_id] = address(0);
            }
        }
    }
    
    
    //
    //                                                                                                              VIEW ФУНКЦИИ
    //
    
    
    function getAd(uint _id) external view returns (uint, uint, uint32, uint32, address)
    {
        // Получить рекламу по id
        Advertisment memory get = ads[_id];
        return (get.id, get.value, get.prop_lifetime, get.lifetime, get.owner);
    }
    
    function getAdsOfOwner () external view returns (uint32[] memory, uint[] memory, uint32[] memory)
    {
        // Вернет все рекламы адреса
        uint32[] memory ids = new uint32[](addressToAds[msg.sender]);
        uint[] memory values = new uint[](addressToAds[msg.sender]);
        uint32[] memory prop_lifetimes = new uint32[](addressToAds[msg.sender]);
        uint32[] memory lifetimes = new uint32[](addressToAds[msg.sender]);
        
        uint counter = 0;
        for(uint i = 0; i < ads.length ; i++)
        {
            if(ads[i].owner == msg.sender){
                ids[counter] = uint32(i);
                values[counter] = ads[i].value;
                prop_lifetimes[counter] = ads[i].prop_lifetime;
                lifetimes[counter] = ads[i].lifetime;
                counter++;
            }
        }
        return (ids, values, lifetimes);
    }
    
    function getRequestsOfUser () external view returns (uint[] memory, uint8[] memory)
    {
        // Вернет все запросы адреса
        uint[] memory values = new uint[](addressToBuyers[msg.sender]);
        uint8[] memory states = new uint8[](addressToBuyers[msg.sender]);
        
        uint counter = 0;
        for(uint i = 0; i < ads.length ; i++)
        {
            if(buyers[i].buyer == msg.sender){
                values[counter] = buyers[i].value;
                states[counter] = buyers[i].state;
                counter++;
            }
        }
        return (values, states);
    }
    
    function getRequestsOfAd (uint _id) external view returns (address[] memory, uint[] memory, uint8[] memory)
    {
        // Вернет все запросы по рекламе
        
        uint size = 0;
        
        for (uint i = 0; i < buyers.length; i++)
        {
            if(buyers[i].adId == _id){
                size++;
            }
        }
        
        
        address[] memory adr = new address[](size);
        uint[] memory values = new uint[](size);
        uint8[] memory states = new uint8[](size);
        
        uint counter = 0;
        for (uint i = 0; i < buyers.length; i++)
        {
            if(buyers[i].adId == _id){
                adr[counter] = buyers[i].buyer;
                values[counter] = buyers[i].value;
                states[counter] = buyers[i].state;
                counter++;
            }
        }
        return (adr, values, states);
    }
    
}
