local RunService = game:GetService("RunService")
local Budget = {}

Budget.SLICE = 1 / 100

function Budget.stepper(slice: number?): () -> ()
	local window = slice or Budget.SLICE
	local deadline = os.clock() + window

	return function()
		if os.clock() < deadline then
			return
		end
		RunService.Heartbeat:Wait()
		deadline = os.clock() + window
	end
end

return Budget
