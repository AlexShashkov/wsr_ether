pragma solidity >= 0.4.1 < 0.6.0;

import "./estate.sol";

contract Buy is Main
{
    
    struct Advertisment
    {
        // Структура рекламы
        uint id;
        uint value;
        uint32 lifetime;
        address owner;
    }
    
    struct Buyer
    {
        // Структура покупателя
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
    
    /*
    Рекламы адреса
    Запросы адреса
    */
    
    
    //
    //                                                                                                                  ЭВЕНТЫ
    //
    
    
    event createAdvertisment
    (
        // Создание рекламы
        uint _id,
        uint _value,
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
    
    
    // 
    //                                                                                                              ФУНКЦИИ
    //
    
    
    function createAd(uint _id, uint _value, uint _lifetime) external ifOwner(msg.sender, _id)
    {
        // Создать объявление о продаже
        uint32 stamp = uint32(now + _lifetime * 1 days);
        ads.push(Advertisment(_id, _value, stamp, msg.sender));
        addressToAds[msg.sender]++;
        emit createAdvertisment(_id, _value, stamp, msg.sender);
    }
    
    function cancellAd(uint _id) external ifOwner(msg.sender, _id)
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
    
    function requestEstate(uint _id) external payable
    {
        // Запросить перевод недвижимости и перевести деньги на хранилище
        require(ads[_id].lifetime > now);
        require(msg.value >= ads[_id].value);
        payToContract(ads[_id].value);
        buyers.push(Buyer(_id, ads[_id].value, 1, msg.sender));
        addressToBuyers[msg.sender]++;
        emit userAskedPurchase(_id, msg.value, msg.sender);
    }
    
    function declineOwner (address _to, uint _id) external
    {
        // отказать в продаже
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
        _transfer(msg.sender, _to, ad.id);
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
        emit ownerAcceptsUser(_to, _id, msg.sender);
    }
    
    
    function checkLifeTime(uint _id) external  
    {
        // Проверить лайфтайм объявления
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
    
    
    //
    //                                                                                                              VIEW ФУНКЦИИ
    //
    
    function getAd(uint _id) external view returns (uint, uint, uint32, address)
    {
        // Получить рекламу по id
        Advertisment memory get = ads[_id];
        return (get.id, get.value, get.lifetime, get.owner);
    }
    
    function getRequest(uint _id) external view returns (uint, uint, uint8, address)
    {
        // Получить рекламу по id
        Buyer memory get = buyers[_id];
        return (get.adId, get.value, get.state, get.buyer);
    }
    
    function getAdsOfOwner () external view returns (uint32[] memory) 
    {
        // Вернет все рекламы адреса
        uint32[] memory ids = new uint32[](addressToAds[msg.sender]);
        
        uint counter = 0;
        for(uint i = 0; i < ads.length ; i++)
        {
            if(ads[i].owner == msg.sender){
                ids[counter] = uint32(i);
                counter++;
            }
        }
        return (ids);
    }
    
    function getRequestsOfUser () external view returns (uint32[] memory) 
    {
        // Вернет все запросы адреса
        uint size = 0;
        
        for (uint i = 0; i < buyers.length; i++)
        {
            if(buyers[i].buyer == msg.sender){
                size++;
            }
        }
        
        uint32[] memory ids = new uint32[](size);
        
        uint counter = 0;
        for(uint i = 0; i < buyers.length ; i++)
        {
            if(buyers[i].buyer == msg.sender){
                ids[counter] = uint32(i);
                counter++;
            }
        }
        return (ids);
    }
    
    function getRequestsOfAd (uint _id) external view returns (uint32[] memory)
    {
        // Вернет всех кто запросил покупку
        uint size = 0;
        
        for (uint i = 0; i < buyers.length; i++)
        {
            if(buyers[i].adId == _id){
                size++;
            }
        }
        
        uint32[] memory ids = new uint32[](size);
        
        uint counter = 0;
        for (uint i = 0; i < buyers.length; i++)
        {
            if(buyers[i].adId == _id){
                ids[counter] = uint32(i);
                counter++;
            }
        }
        return (ids);
    }
    
}
