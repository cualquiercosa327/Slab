--[[

MIT License

Copyright (c) 2019 Mitchell Davis <coding.jackalope@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

--]]

local Button = require(SLAB_PATH .. '.Internal.UI.Button')
local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local Input = require(SLAB_PATH .. '.Internal.UI.Input')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Style = require(SLAB_PATH .. '.Style')
local Text = require(SLAB_PATH .. '.Internal.UI.Text')
local Utility = require(SLAB_PATH .. '.Internal.Core.Utility')
local Window = require(SLAB_PATH .. '.Internal.UI.Window')

local ColorPicker = {}

local SaturationCanvas = nil
local SaturationMeshes = nil
local SaturationSize = 200.0
local SaturationStep = 5
local SaturationData = nil
local SaturationRender = false
local SaturationFocused = false

local TintCanvas = nil
local TintMeshes = nil
local TintW = 30.0
local TintH = SaturationSize
local TintData = nil
local TintFocused = false

local CurrentColor = {1.0, 1.0, 1.0, 1.0}
local ColorH = 25.0

local function InputColor(Component, Value, OffsetX)
	local Changed = false
	Text.Begin(string.format("%s ", Component))
	Cursor.SameLine()
	Cursor.SetRelativeX(OffsetX)
	if Input.Begin('ColorPicker_' .. Component, {W = 40.0, NumbersOnly = true, Text = math.ceil(Value * 255), ReturnOnText = false}) then
		local NewValue = tonumber(Input.GetText())
		if NewValue ~= nil then
			NewValue = math.max(NewValue, 0)
			NewValue = math.min(NewValue, 255)
			Value = NewValue / 255
			Changed = true
		end
	end
	return Value, Changed
end

local function UpdateSaturationColors()
	if SaturationMeshes ~= nil then
		SaturationRender = true
		local MeshIndex = 1
		local Step = SaturationStep
		local C00 = {1.0, 1.0, 1.0, 1.0}
		local C10 = {1.0, 1.0, 1.0, 1.0}
		local C01 = {1.0, 1.0, 1.0, 1.0}
		local C11 = {1.0, 1.0, 1.0, 1.0}
		local StepX, StepY = 0, 0
		local Hue, Sat, Val = Utility.RGBtoHSV(CurrentColor[1], CurrentColor[2], CurrentColor[3])

		for I = 1, Step, 1 do
			for J = 1, Step, 1 do
				local S0 = StepX / Step
				local S1 = (StepX + 1) / Step
				local V0 = 1.0 - (StepY / Step)
				local V1 = 1.0 - ((StepY + 1) / Step)

				C00[1], C00[2], C00[3] = Utility.HSVtoRGB(Hue, S0, V0)
				C10[1], C10[2], C10[3] = Utility.HSVtoRGB(Hue, S1, V0)
				C01[1], C01[2], C01[3] = Utility.HSVtoRGB(Hue, S0, V1)
				C11[1], C11[2], C11[3] = Utility.HSVtoRGB(Hue, S1, V1)

				local Mesh = SaturationMeshes[MeshIndex]
				MeshIndex = MeshIndex + 1

				Mesh:setVertexAttribute(1, 3, C00[1], C00[2], C00[3], C00[4])
				Mesh:setVertexAttribute(2, 3, C10[1], C10[2], C10[3], C10[4])
				Mesh:setVertexAttribute(3, 3, C11[1], C11[2], C11[3], C11[4])
				Mesh:setVertexAttribute(4, 3, C01[1], C01[2], C01[3], C01[4])

				StepX = StepX + 1
			end

			StepX = 0
			StepY = StepY + 1
		end
	end
end

local function InitializeSaturationCanvas()
	if SaturationCanvas == nil then
		SaturationCanvas = love.graphics.newCanvas(SaturationSize, SaturationSize)

		SaturationMeshes = {}
		local Step = SaturationStep
		local X, Y = 0.0, 0.0
		local Size = SaturationSize / Step

		for I = 1, Step, 1 do
			for J = 1, Step, 1 do
				local Verts = {
					{
						X, Y,
						0.0, 0.0
					},
					{
						X + Size, Y,
						0.0, 0.0
					},
					{
						X + Size, Y + Size,
						0.0, 0.0
					},
					{
						X, Y + Size,
						0.0, 0.0
					}
				}

				local NewMesh = love.graphics.newMesh(Verts)
				table.insert(SaturationMeshes, NewMesh)

				X = X + Size
			end

			X = 0.0
			Y = Y + Size
		end
	end

	UpdateSaturationColors()
end

local function InitializeTintCanvas()
	if TintCanvas == nil then
		TintCanvas = love.graphics.newCanvas(TintW, TintH)

		TintMeshes = {}
		local Step = 6
		local X, Y = 0.0, 0.0
		local C0 = {1.0, 1.0, 1.0, 1.0}
		local C1 = {1.0, 1.0, 1.0, 1.0}
		local I = 0
		local Colors = {
			{1.0, 0.0, 0.0, 1.0},
			{1.0, 1.0, 0.0, 1.0},
			{0.0, 1.0, 0.0, 1.0},
			{0.0, 1.0, 1.0, 1.0},
			{0.0, 0.0, 1.0, 1.0},
			{1.0, 0.0, 1.0, 1.0},
			{1.0, 0.0, 0.0, 1.0}
		}

		for Index = 1, Step, 1 do
			C0 = Colors[Index]
			C1 = Colors[Index + 1]
			local Verts = {
				{
					X, Y,
					0.0, 0.0,
					C0[1], C0[2], C0[3], C0[4]
				},
				{
					TintW, Y,
					1.0, 0.0,
					C0[1], C0[2], C0[3], C0[4]
				},
				{
					TintW, Y + TintH / Step,
					1.0, 1.0,
					C1[1], C1[2], C1[3], C1[4]
				},
				{
					X, Y + TintH / Step,
					0.0, 1.0,
					C1[1], C1[2], C1[3], C1[4]
				}
			}

			local NewMesh = love.graphics.newMesh(Verts)
			table.insert(TintMeshes, NewMesh)

			Y = Y + TintH / Step
		end
	end
end

function ColorPicker.Begin(Options)
	Options = Options == nil and {} or Options
	Options.Color = Options.Color == nil and {1.0, 1.0, 1.0, 1.0} or Options.Color

	local DeltaVisibleTime = love.timer.getTime() - Window.GetLastVisibleTime('ColorPicker')
	if DeltaVisibleTime > 1.0 then
		CurrentColor[1] = Options.Color[1]
		CurrentColor[2] = Options.Color[2]
		CurrentColor[3] = Options.Color[3]
		CurrentColor[4] = Options.Color[4]
		UpdateSaturationColors()
	end

	Window.Begin('ColorPicker', {Title = "Color Picker"})

	local X, Y = Cursor.GetPosition()
	local MouseX, MouseY = Window.GetMousePosition()
	local H, S, V = Utility.RGBtoHSV(CurrentColor[1], CurrentColor[2], CurrentColor[3])
	local UpdateColor = false

	if SaturationCanvas ~= nil then
		DrawCommands.DrawCanvas(SaturationCanvas, X, Y)
		Window.AddItem(X, Y, SaturationCanvas:getWidth(), SaturationCanvas:getHeight())

		local UpdateSaturation = false
		if X <= MouseX and MouseX < X + SaturationCanvas:getWidth() and Y <= MouseY and MouseY < Y + SaturationCanvas:getHeight() then
			if Mouse.IsClicked(1) then
				SaturationFocused = true
				UpdateSaturation = true
			end
		end

		if SaturationFocused and Mouse.IsDragging(1) then
			UpdateSaturation = true
		end

		if UpdateSaturation then
			local CanvasX = math.max(MouseX - X, 0)
			CanvasX = math.min(CanvasX, SaturationData:getWidth() - 1)

			local CanvasY = math.max(MouseY - Y, 0)
			CanvasY = math.min(CanvasY, SaturationData:getHeight() - 1)

			S = CanvasX / (SaturationData:getWidth() - 1)
			V = 1 - (CanvasY / (SaturationData:getHeight() - 1))

			UpdateColor = true
		end

		local SaturationX = S * (SaturationData:getWidth() - 1)
		local SaturationY = (1.0 - V) * (SaturationData:getHeight() - 1)
		DrawCommands.Circle('line', X + SaturationX, Y + SaturationY, 4.0, {1.0, 1.0, 1.0, 1.0})

		X = X + SaturationCanvas:getWidth() + Cursor.PadX()
	end

	if TintCanvas ~= nil then
		DrawCommands.DrawCanvas(TintCanvas, X, Y)
		Window.AddItem(X, Y, TintCanvas:getWidth(), TintCanvas:getHeight())

		local UpdateTint = false
		if X <= MouseX and MouseX < X + TintCanvas:getWidth() and Y <= MouseY and MouseY < Y + TintCanvas:getHeight() then
			if Mouse.IsClicked(1) then
				TintFocused = true
				UpdateTint = true
			end
		end

		if TintFocused and Mouse.IsDragging(1) then
			UpdateTint = true
		end

		if UpdateTint then
			local CanvasY = math.max(MouseY - Y, 0)
			CanvasY = math.min(CanvasY, TintCanvas:getHeight() - 1)

			H = CanvasY / (TintCanvas:getHeight() - 1)

			UpdateColor = true
		end

		local TintY = H * (TintCanvas:getHeight() - 1)
		DrawCommands.Line(X, Y + TintY, X + TintCanvas:getWidth(), Y + TintY, 2.0, {1.0, 1.0, 1.0, 1.0})

		Y = Y + TintCanvas:getHeight() + Cursor.PadY()
	end

	if UpdateColor then
		CurrentColor[1], CurrentColor[2], CurrentColor[3] = Utility.HSVtoRGB(H, S, V)
		UpdateSaturationColors()
	end

	local OffsetX = Text.GetWidth("##")
	Cursor.AdvanceY(SaturationSize)
	X, Y = Cursor.GetPosition()
	local OldColor = {CurrentColor[1], CurrentColor[2], CurrentColor[3], CurrentColor[4]}
	local R = tonumber(string.format("%.2f", CurrentColor[1]))
	local G = tonumber(string.format("%.2f", CurrentColor[2]))
	local B = tonumber(string.format("%.2f", CurrentColor[3]))
	local A = tonumber(string.format("%.2f", CurrentColor[4]))

	CurrentColor[1], R = InputColor("R", R, OffsetX)
	CurrentColor[2], G = InputColor("G", G, OffsetX)
	CurrentColor[3], B = InputColor("B", B, OffsetX)
	CurrentColor[4], A = InputColor("A", A, OffsetX)

	if R or G or B or A then
		UpdateSaturationColors()
	end

	local InputX, InputY = Cursor.GetPosition()
	Cursor.SameLine()
	X = Cursor.GetX()
	Cursor.SetY(Y)

	local WinX, WinY, WinW, WinH = Window.GetBounds()
	WinW, WinH = Window.GetBorderlessSize()

	OffsetX = Text.GetWidth("####")
	local ColorX = X + OffsetX

	local ColorW = (WinX + WinW) - ColorX
	DrawCommands.Rectangle('fill', ColorX, Y, ColorW, ColorH, CurrentColor, Style.ButtonRounding)
	Window.AddItem(X, Y, ColorW, ColorH)

	local LabelW, LabelH = Text.GetSize("New")
	Cursor.SetPosition(ColorX - LabelW - Cursor.PadX(), Y + (ColorH * 0.5) - (LabelH * 0.5))
	Text.Begin("New")

	Y = Y + ColorH + Cursor.PadY()

	DrawCommands.Rectangle('fill', ColorX, Y, ColorW, ColorH, Options.Color, Style.ButtonRounding)
	Window.AddItem(X, Y, ColorW, ColorH)

	local LabelW, LabelH = Text.GetSize("Old")
	Cursor.SetPosition(ColorX - LabelW - Cursor.PadX(), Y + (ColorH * 0.5) - (LabelH * 0.5))
	Text.Begin("Old")

	if Mouse.IsReleased(1) then
		SaturationFocused = false
		TintFocused = false
	end

	Cursor.SetPosition(InputX, InputY)
	Cursor.NewLine()

	local Result = {Button = "", Color = CurrentColor}
	if Button.Begin("Cancel", {AlignRight = true}) then
		Result.Button = "Cancel"
	end

	Cursor.SameLine()

	if Button.Begin("OK", {AlignRight = true}) then
		Result.Button = "OK"
	end

	Window.End()

	return Result
end

function ColorPicker.DrawCanvas()
	if SaturationCanvas == nil then
		InitializeSaturationCanvas()
	end

	if SaturationRender then
		SaturationRender = false
		love.graphics.setCanvas(SaturationCanvas)
		for I, V in ipairs(SaturationMeshes) do
			love.graphics.draw(V)
		end
		love.graphics.setCanvas()

		SaturationData = SaturationCanvas:newImageData()
	end

	if TintCanvas == nil then
		InitializeTintCanvas()

		love.graphics.setCanvas(TintCanvas)
		for I, V in ipairs(TintMeshes) do
			love.graphics.draw(V)
		end
		love.graphics.setCanvas()

		TintData = TintCanvas:newImageData()
	end
end

return ColorPicker
