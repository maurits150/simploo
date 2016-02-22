print("-----------------")
print("--- benchmark ---")
print("-----------------")
namespace "Benchmark"

class "Simple" {
    private {
        privateMember1 = function() end;
        privateMember2 = function() end;
        privateMember3 = function() end;
        privateMember4 = function() end;
        privateMember5 = function() end;
        privateMember6 = "Content";
        privateMember7 = "Content";
        privateMember8 = "Content";
        privateMember9 = "Content";
        privateMember10 = "Content";
    };

    public {
        publicMember1 = function() end;
        publicMember2 = function() end;
        publicMember3 = function() end;
        publicMember4 = function() end;
        publicMember5 = function() end;
        publicMember6 = "Content";
        publicMember7 = "Content";
        publicMember8 = "Content";
        publicMember9 = "Content";
        publicMember10 = "Content";
    };
};

local startTime = os.clock()

for i=1, 10000 do
    Benchmark.Simple.new()
end


print("completed 10k new instances in " .. (os.clock() - startTime))
print("-----------------")
