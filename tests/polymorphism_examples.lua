--[[
    Additional polymorphism examples for documentation.
    Run with: printf '4\n5' | lua menu.lua
]]

-- Template Method Pattern: Parent defines algorithm skeleton, child fills in steps
function Test:testTemplateMethodPattern()
    class "DataProcessor" {
        -- Template method - defines the algorithm skeleton
        process = function(self)
            local data = self:fetchData()
            local transformed = self:transform(data)
            return self:format(transformed)
        end;
        
        -- Default implementations (can be overridden)
        fetchData = function(self)
            return "raw"
        end;
        
        transform = function(self)
            return "transformed"
        end;
        
        format = function(self, data)
            return "[" .. data .. "]"
        end;
    }
    
    class "JsonProcessor" extends "DataProcessor" {
        transform = function(self, data)
            return '{"data":"' .. data .. '"}'
        end;
    }
    
    class "XmlProcessor" extends "DataProcessor" {
        transform = function(self, data)
            return '<data>' .. data .. '</data>'
        end;
        
        format = function(self, data)
            return '<?xml version="1.0"?>' .. data
        end;
    }
    
    local json = JsonProcessor.new()
    local xml = XmlProcessor.new()
    
    -- JsonProcessor uses its own transform, parent's format
    assertEquals(json:process(), '[{"data":"raw"}]')
    
    -- XmlProcessor overrides both transform and format
    assertEquals(xml:process(), '<?xml version="1.0"?><data>raw</data>')
end

-- Polymorphism in constructor: Be careful - child fields may not be initialized yet!
function Test:testPolymorphismInConstructor()
    class "Widget" {
        name = "";
        
        __construct = function(self)
            -- This will call the child's getName() if overridden
            self.name = self:getName()
        end;
        
        getName = function(self)
            return "Widget"
        end;
    }
    
    class "Button" extends "Widget" {
        label = "Click me";
        
        -- Note: No constructor, so parent's runs automatically
        getName = function(self)
            return "Button:" .. self.label
        end;
    }
    
    local btn = Button.new()
    -- Child's getName() is called during parent constructor
    assertEquals(btn.name, "Button:Click me")
end

-- Recursive method with polymorphism
function Test:testRecursivePolymorphism()
    class "TreeNode" {
        value = 0;
        children = null;
        
        __construct = function(self, val)
            self.value = val
            self.children = {}
        end;
        
        addChild = function(self, child)
            table.insert(self.children, child)
            return self
        end;
        
        -- Polymorphic - child classes can override to change calculation
        calculate = function(self)
            local sum = self:getValue()
            for _, child in ipairs(self.children) do
                sum = sum + child:calculate()  -- Recursive + polymorphic
            end
            return sum
        end;
        
        getValue = function(self)
            return self.value
        end;
    }
    
    class "DoubleNode" extends "TreeNode" {
        getValue = function(self)
            return self.value * 2
        end;
    }
    
    -- Tree: root(10) -> child1(5), child2(DoubleNode:3)
    local root = TreeNode.new(10)
    local child1 = TreeNode.new(5)
    local child2 = DoubleNode.new(3)  -- This will contribute 6
    
    root:addChild(child1)
    root:addChild(child2)
    
    -- 10 + 5 + 6 = 21
    assertEquals(root:calculate(), 21)
end

-- Chain of responsibility with polymorphism
function Test:testChainOfResponsibility()
    class "Handler" {
        successor = null;
        
        setSuccessor = function(self, handler)
            self.successor = handler
            return self
        end;
        
        handle = function(self, request)
            if self:canHandle(request) then
                return self:doHandle(request)
            elseif self.successor then
                return self.successor:handle(request)
            else
                return "unhandled"
            end
        end;
        
        -- Override these in subclasses
        canHandle = function(self, request)
            return false
        end;
        
        doHandle = function(self, request)
            return "base"
        end;
    }
    
    class "NumberHandler" extends "Handler" {
        canHandle = function(self, request)
            return type(request) == "number"
        end;
        
        doHandle = function(self, request)
            return "number:" .. request
        end;
    }
    
    class "StringHandler" extends "Handler" {
        canHandle = function(self, request)
            return type(request) == "string"
        end;
        
        doHandle = function(self, request)
            return "string:" .. request
        end;
    }
    
    local chain = NumberHandler.new():setSuccessor(StringHandler.new())
    
    assertEquals(chain:handle(42), "number:42")
    assertEquals(chain:handle("hello"), "string:hello")
    assertEquals(chain:handle({}), "unhandled")
end

-- Multiple inheritance: method from one parent calling method from another
-- (This shows polymorphism works across the inheritance diamond)
function Test:testPolymorphismWithMultipleInheritance()
    class "Describable" {
        getDescription = function(self)
            return "unknown"
        end;
        
        describe = function(self)
            return "I am: " .. self:getDescription()
        end;
    }
    
    class "Identifiable" {
        id = 0;
        
        getId = function(self)
            return self.id
        end;
    }
    
    class "Entity" extends "Describable, Identifiable" {
        name = "";
        
        __construct = function(self, id, name)
            self.id = id
            self.name = name
        end;
        
        -- Override from Describable
        getDescription = function(self)
            return self.name .. " (id:" .. self:getId() .. ")"
        end;
    }
    
    local e = Entity.new(42, "Player")
    
    -- describe() is from Describable, but calls our overridden getDescription()
    -- which in turn calls getId() from Identifiable
    assertEquals(e:describe(), "I am: Player (id:42)")
end

-- Super call in middle of chain
function Test:testSuperCallInMiddle()
    class "A" {
        getValue = function(self)
            return "A"
        end;
    }
    
    class "B" extends "A" {
        getValue = function(self)
            return "B+" .. self.A:getValue()
        end;
    }
    
    class "C" extends "B" {
        getValue = function(self)
            return "C+" .. self.B:getValue()
        end;
    }
    
    local c = C.new()
    -- C calls B which calls A
    assertEquals(c:getValue(), "C+B+A")
end

-- Factory method pattern
function Test:testFactoryMethodPattern()
    class "Document" {
        content = "";
        
        -- Factory method - child classes override to create different pages
        createPage = function(self)
            return "GenericPage"
        end;
        
        addContent = function(self, text)
            self.content = self.content .. self:createPage() .. ":" .. text .. "\n"
        end;
    }
    
    class "Report" extends "Document" {
        createPage = function(self)
            return "ReportPage"
        end;
    }
    
    class "Resume" extends "Document" {
        createPage = function(self)
            return "ResumePage"
        end;
    }
    
    local report = Report.new()
    report:addContent("Q1 Sales")
    report:addContent("Q2 Sales")
    
    local resume = Resume.new()
    resume:addContent("Experience")
    
    assertEquals(report.content, "ReportPage:Q1 Sales\nReportPage:Q2 Sales\n")
    assertEquals(resume.content, "ResumePage:Experience\n")
end

-- State pattern - object behavior changes based on internal state
function Test:testStatePattern()
    class "State" {
        handle = function(self, context)
            return "default"
        end;
    }
    
    class "IdleState" extends "State" {
        handle = function(self, context)
            return "idle"
        end;
    }
    
    class "RunningState" extends "State" {
        handle = function(self, context)
            return "running at " .. context.speed
        end;
    }
    
    class "Machine" {
        state = null;
        speed = 100;
        
        __construct = function(self)
            self.state = IdleState.new()
        end;
        
        setState = function(self, state)
            self.state = state
        end;
        
        process = function(self)
            -- Polymorphic call - different states produce different results
            return self.state:handle(self)
        end;
    }
    
    local m = Machine.new()
    assertEquals(m:process(), "idle")
    
    m:setState(RunningState.new())
    assertEquals(m:process(), "running at 100")
end

-- Visitor pattern - double dispatch
function Test:testVisitorPattern()
    class "Visitor" {
        visitCircle = function(self, circle)
            return "circle"
        end;
        
        visitSquare = function(self, square)
            return "square"
        end;
    }
    
    class "AreaVisitor" extends "Visitor" {
        visitCircle = function(self, circle)
            return 3.14 * circle.radius * circle.radius
        end;
        
        visitSquare = function(self, square)
            return square.side * square.side
        end;
    }
    
    class "Shape" {
        accept = function(self, visitor)
            return "unknown"
        end;
    }
    
    class "Circle" extends "Shape" {
        radius = 0;
        
        __construct = function(self, r)
            self.radius = r
        end;
        
        accept = function(self, visitor)
            return visitor:visitCircle(self)
        end;
    }
    
    class "Square" extends "Shape" {
        side = 0;
        
        __construct = function(self, s)
            self.side = s
        end;
        
        accept = function(self, visitor)
            return visitor:visitSquare(self)
        end;
    }
    
    local shapes = {Circle.new(2), Square.new(3)}
    local areaVisitor = AreaVisitor.new()
    
    local areas = {}
    for _, shape in ipairs(shapes) do
        table.insert(areas, shape:accept(areaVisitor))
    end
    
    assertEquals(areas[1], 3.14 * 4)  -- circle area
    assertEquals(areas[2], 9)          -- square area
end
