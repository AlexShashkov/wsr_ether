pragma solidity >= 0.4.1 < 0.6.0;

contract Vote
{
    
    address creator;
    
    // Адрес создателя
    
    constructor() public{
        // Конструктор, назначаем создателя
        creator = msg.sender;
    }
    
    modifier ifOwner(address _sender){
        // modifier если владелец
        require(_sender == creator);
        _;
    }
    
    
    struct Candidate
    {
        // Структура кандидата
       string description;
       address sender;
    }
    
    Candidate[] candidates;
    
    mapping(uint => uint) idToCount;
    mapping(address => bool) electorToVote;
    
    // Получить кол-во голосов по id
    // Узнать, проголосовал ли адрес
    
    function createCandidate(string memory _description) public
    {
        // Создать анкету кандидата
        for(uint i = 0; i < candidates.length; i++){
           if(candidates[i].sender == msg.sender)
            revert("You have registered as candidate already");
        }
        candidates.push(Candidate(_description, msg.sender));
    }
    
    function vote(uint _id) external
    {
        // Проголосовать за кандидата
        require(electorToVote[msg.sender] != true, "You have voted already");
        electorToVote[msg.sender] = true;
        idToCount[_id]++;
    }
    
    function getWinner() ifOwner(msg.sender) external view returns(uint, uint, uint[] memory){
        // Получить победителя и узнать кто прошел во второй тур
        uint winner;
        uint max;
        uint[] memory tour;
        (winner, max) = getMax();
        tour = newTour(max);
        return (winner, max, tour);
    }
    
    function getMax() internal view returns(uint, uint)
    {
        // Получить человека с наибольшим кол-вом голосов
        uint max = 0;
        uint winner;
        for(uint i= 0; i < candidates.length; i++){
          if(idToCount[i] > max)
          {
             winner = i;
             max = idToCount[i];
          }
        }
        return (winner, max);
    }
    
    function newTour(uint _max) internal view returns(uint[] memory){
        // Кто прошел во второй тур
        uint size;
        for(uint i= 0; i < candidates.length; i++){
            if(idToCount[i] == _max || idToCount[i]*100 >= _max*80){
               size++; 
            }
        }
        uint[] memory tour = new uint[](size);
        
        uint counter = 0;
        for(uint i= 0; i < candidates.length; i++){
            if(idToCount[i] == _max || idToCount[i]*100 >= _max*80){
               tour[counter] = i;
               counter++;
            }
        }
        
        return tour;
    }
    
    
    function getCandidate(uint _id) public view returns (string memory){
        // Получить кандидата
        return candidates[_id].description;
    }
    
    function getCandidatesStat(uint _id) ifOwner(msg.sender) public view returns (uint){
        // Узнать статус кандидата
        return idToCount[_id];
    }
    
}
