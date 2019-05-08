pragma solidity >= 0.4.1 < 0.6.0;

contract Manager
{
    struct Loan {
        // Структура на заем
        // Заемодатель
        // Заемщик
        // Заем
        // Штраф (налог)
        // Цикл штрафа
        // Жизнь рекламы
        // Активен ли заем
        address loaner;
        address borrower;
        uint value;
        uint fine;
        uint lifetime;
        uint adLifetime;
        bool active;
    }
    
    struct Request {
        // Запрос на заем
        // id заема 
        // заемщик
        // статус
        uint id;
        address borrower;
        uint status;
    }
    
    //СТАТУСЫ:
    // 0 - неизвестно
    // 1 - принят
    // 2 - отказано
    
    // Заемы
    // запросы
    
    // Кол-во заемов пользователей
    // Кол-во запросов пользователей
    
    Loan[] loans;
    Request[] requests;
    
    mapping(address => uint) usersLoans;
    mapping(address => uint) usersRequests;
    
    
    //                                                              ФУНКЦИИ
    
    
    function pay(address _to, uint _value) public payable{
        // Передать эфир
        require(msg.value >= _value);
        address payable addr = address(uint160(_to));
        addr.transfer(_value);
    }
    
    function payToContract(uint _value) public payable{
        // Передать эфир контракту
        require(msg.value >= _value);
    }
    
    function getFromContract(address _addr, uint _value) internal
    {
        // Получить эфир с контракта
        address payable to = address(uint160(_addr));
        to.transfer(_value);
    }
    
    
    function createLoan(uint _value, uint _fine, uint _lifetime, uint _adLifetime) public payable{
        // Создать объявление о заеме
        require(msg.value >= _value);
        payToContract(_value);
        loans.push(Loan(msg.sender, address(0), _value, _fine, _lifetime, now + (_adLifetime * 1 seconds), false));
        usersLoans[msg.sender]++;
    }
    
    function requestLoan(uint _id) public {
        // Запросить заем
        require (now < loans[_id].adLifetime);
        requests.push(Request(_id, msg.sender, 0));
        usersRequests[msg.sender]++;
    }
    
    function closeRequests(uint _id) internal{
        // Закрыть все заемы
        require(loans[_id].active == false);
        for(uint i = 0; i < requests.length; i++){
            if(requests[i].id == _id)
                if(requests[i].status == 0)
                    requests[i].status = 2;
        }
        loans[_id].adLifetime = now;
        getFromContract(loans[_id].loaner, loans[_id].value);
    }
    
    function denyAllRequests(uint _id) public{
        // Закрыть все заемы заемодателем
        require(msg.sender == loans[_id].loaner);
        closeRequests(_id);
    }
    
    function acceptRequest(uint _id, uint _requestId) public{
        // Принять заем
        require(loans[_id].active == false);
        require(now < loans[_id].adLifetime);
        require(requests[_requestId].id == _id);
        requests[_requestId].status = 1;
        for(uint i = 0; i < requests.length; i++){
            if(requests[i].id == _id)
                if(requests[i].status == 0)
                    requests[i].status = 2;
        }
        loans[_id].borrower = requests[_requestId].borrower;
        loans[_id].lifetime = now + 1 seconds * loans[_id].lifetime;
        loans[_id].adLifetime = now;
        loans[_id].active = true;
        getFromContract(requests[_requestId].borrower, loans[_id].value);
    }
    
    function declineRequest(uint _id, uint _requestId) public{
        // отклонить заем
        require(loans[_id].active == false);
        require(loans[_id].adLifetime < now);
        require(requests[_requestId].id == _id);
        requests[_requestId].status = 2;
    }
    
    function payLoan(uint _id) external payable{
        // Оплатить заем
        require(loans[_id].active == true);
        require(msg.sender == loans[_id].borrower);
        pay(loans[_id].loaner, loans[_id].value);
        loans[_id].active = false;
        loans[_id].lifetime = now;
    }
    
    function checkFine(uint _id) internal{
        // Назначить "штраф"
        require(loans[_id].active == true);
        if(now >= loans[_id].lifetime){
            loans[_id].value += loans[_id].fine;
            loans[_id].lifetime = (now + 50 seconds); // TODO: SWITCH SECONDS TO DAYS
        }
    }
    
    function checkAdLifeTime(uint _id) public{
        // Проверка актуальности рекламы о заеме
        if(loans[_id].adLifetime < now)
            closeRequests(_id);
    }
    
    
    //                                                              VIEW ФУНКЦИИ
    
    
    function getLoan(uint _id) external view returns(address, address, uint, uint, uint, uint){
        require(loans[_id].loaner == msg.sender);
        Loan memory get = loans[_id];
        return(get.loaner, get.borrower, get.value, get.fine, get.lifetime, get.adLifetime);
    }
    
    function getRequest(uint _id) external view returns(uint, address, uint) {
        require(requests[_id].borrower == msg.sender || loans[requests[_id].id].loaner == msg.sender);
        Request memory get = requests[_id];
        return(get.id, get.borrower, get.status);
    }
    
    function getRequestsOfLoan(uint _id) external view returns(uint[] memory){ 
        uint size = 0;
        for(uint i = 0; i < requests.length; i++){
            if(requests[i].id == _id)
                size++;
        }
        
        uint[] memory _requests = new uint[](size);
        uint counter = 0;
        for(uint i = 0; i < requests.length; i++){
            if(requests[i].id == _id){
                _requests[counter] = i;
                counter++;
            }
        }
        return _requests;
    }
    
    function getUserLoans() external view returns(uint[] memory){
        uint[] memory _loans = new uint[](usersLoans[msg.sender]);
        uint counter = 0;
        for(uint i = 0; i < loans.length; i++){
            if(loans[i].loaner == msg.sender){
             _loans[counter] = i;   
             counter++;
            }
        }
        return _loans;
    }
    
    function getUserRequests() external view returns(uint[] memory){
        uint[] memory _requests = new uint[](usersRequests[msg.sender]);
        uint counter = 0;
        for(uint i = 0; i < requests.length; i++){
            if(requests[i].borrower == msg.sender){
                _requests[counter] = i;
                counter ++;
            }
        }
        return _requests;
    }
    
    function seeContractValue() external view returns(uint){
        return address(this).balance;
    }
    
    function getStamp() external view returns(uint){
        return now;
    }
    
    
}
