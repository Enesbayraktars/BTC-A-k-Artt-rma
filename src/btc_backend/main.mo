import Result "mo:base/Result";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";

actor AuctionContract {
    // Item structure
    public type Item = {
        itemId: Nat;
        itemTokens: [Nat];
    };

    // Participant structure
    public type Participant = {
        remainingTokens: Nat;
        participantId: Nat;
        address: Principal;
    };

    // Auction status
    public type AuctionStatus = {
        #Pending;
        #Completed;
    };

    // Data stores
    private var tokenDetails = HashMap.HashMap<Principal, Participant>(10, Principal.equal, Principal.hash);
    private var participants = Array.init<Participant>(4, {
        remainingTokens = 0;
        participantId = 0;
        address = Principal.fromText("aaaaa-aa")
    });
    private var items = Array.init<Item>(3, {
        itemId = 0;
        itemTokens = []
    });
    private let winners = Array.init<Principal>(3, Principal.fromText("aaaaa-aa"));
    
    private var beneficiary : Principal = Principal.fromActor(AuctionContract);
    private var participantCount : Nat = 0;

    // Auction status variable
    private var auctionStatus : AuctionStatus = #Pending;

    // Initial setup
    public shared(msg) func initialize() : async () {
        beneficiary := msg.caller;

        // Initialize items
        items[0] := {
            itemId = 0;
            itemTokens = []
        };
        items[1] := {
            itemId = 1;
            itemTokens = []
        };
        items[2] := {
            itemId = 2;
            itemTokens = []
        }
    };

    // Registration function
    public shared(msg) func registerParticipant() : async Result.Result<Participant, Text> {
        if (participantCount >= 4) {
            return #err("Maximum participant limit reached")
        };

        let newParticipant : Participant = {
            remainingTokens = 5;
            participantId = participantCount;
            address = msg.caller
        };

        participants[participantCount] := newParticipant;
        tokenDetails.put(msg.caller, newParticipant);
        participantCount += 1;

        #ok(newParticipant)
    };

    // Bidding function
    public shared(msg) func placeBid(itemId : Nat, tokenCount : Nat) : async Result.Result<(), Text> {
        switch (tokenDetails.get(msg.caller)) {
            case null { return #err("Not registered") };
            case (?participant) {
                if (participant.remainingTokens < tokenCount 
                    or participant.remainingTokens == 0 
                    or itemId > 2) {
                    return #err("Invalid bid")
                };

                // Update token balance
                let newBalance = participant.remainingTokens - tokenCount;
                let updatedParticipant : Participant = {
                    remainingTokens = newBalance;
                    participantId = participant.participantId;
                    address = participant.address
                };

                tokenDetails.put(msg.caller, updatedParticipant);
                participants[participant.participantId] := updatedParticipant;

                // Add tokens to item
                var tokenArray = items[itemId].itemTokens;
                var newTokenArray = Array.tabulate<Nat>(
                    tokenArray.size() + tokenCount, 
                    func(i) {
                        if (i < tokenArray.size()) {
                            tokenArray[i]
                        } else {
                            participant.participantId
                        }
                    }
                );

                items[itemId] := {
                    itemId = itemId;
                    itemTokens = newTokenArray
                };

                #ok()
            }
        }
    };

    // Reveal winners function
    public shared(msg) func revealWinners() : async Result.Result<[Principal], Text> {
        // Only owner can call
        if (msg.caller != beneficiary) {
            return #err("Only contract owner can call")
        };

        // Check if auction is already completed
        if (auctionStatus == #Completed) {
            return #err("Auction already completed")
        };

        for (id in Iter.range(0, 2)) {
            let currentItem = items[id];
            
            if (currentItem.itemTokens.size() > 0) {
                // Hash item ID into a string, and use it for selecting winner
                let hashValue = Text.hash(debug_show(id)); // Hash of the item id
                
                // Convert hash value to a number (using the first few characters)
                let slice = Text.slice(hashValue, 0, 8); // Take the first 8 characters
                let hashNat = Nat.fromText(slice); // Convert to Nat

                let randomIndex = Nat.mod(hashNat, Nat.fromNat(currentItem.itemTokens.size()));

                let winningTokenId = currentItem.itemTokens[randomIndex];
                winners[id] := participants[winningTokenId].address;
            }
        };

        auctionStatus := #Completed;
        #ok(Iter.toArray(winners.vals()))
    };

    // Detail retrieval functions
    public query func getParticipantDetails(id : Nat) : async Participant {
        participants[id]
    };

    public query func getItemDetails(id : Nat) : async (Nat, Nat) {
        (items[id].itemId, items[id].itemTokens.size())
    };

    public query func getWinnerDetails() : async [Principal] {
        Iter.toArray(winners.vals())
    }
}
