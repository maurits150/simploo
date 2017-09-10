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


print("completed 10k new instances with 20 members in " .. (os.clock() - startTime))
print("-----------------")

class "Calls1" {
    public {
        doCalls1 = function()
            
        end
    };
};

class "Calls2" extends "Calls1" {
    public {
        doCalls2 = function(self)
            self:doCalls1()
        end
    };
};

class "Calls3" extends "Calls2" {
    public {
        doCalls3 = function(self)
            self:doCalls2()
        end
    };
};

class "Calls4" extends "Calls3" {
    public {
        doCalls4 = function(self)
            self:doCalls3()
        end
    };
};

class "Calls5" extends "Calls4" {
    public {
        doCalls5 = function(self)
            self:doCalls4()
        end
    };
};

local startTime = os.clock()

local instance = Benchmark.Calls5:new()

for i=1, 100000 do
    instance:doCalls5()    
end


print("completed 100k calls to 5 layer deep class in " .. (os.clock() - startTime))
print("-----------------")
