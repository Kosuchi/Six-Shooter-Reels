// ============================================================================
// SIX-SHOOTER REELS - AppGameKit Studio (Tier 1 BASIC)
// Match 3 to 5+ in a row. Slot-machine symbols are DRAWN BY THE ENGINE
// (DrawBox / DrawLine / DrawEllipse) - no image files, no media folder needed.
//
// Controls: click/tap a tile, then a neighbouring tile to swap them. ESC = quit.
// Scoring : 3 in a row = 30, 4 = 60, 5+ = 150 and clears EVERY tile with that
//           symbol ("jackpot", +200). Cascades multiply the score (x2, x3 ...).
//           Reach the target score before you run out of shots.
// ============================================================================

// --- Window / display --------------------------------------------------------
SetWindowTitle("Six-Shooter Reels")
SetWindowSize(960, 640, 0)
SetWindowAllowResize(1)
SetVirtualResolution(960, 640)
SetOrientationAllowed(0, 0, 1, 1)
SetSyncRate(60, 0)
SetScissor(0, 0, 0, 0)
SetClearColor(110, 70, 35)

// --- Constants ---------------------------------------------------------------
#constant COLS 8
#constant ROWS 8
#constant TILE 64
#constant NSYM 6              // 1=Cherry 2=Lemon 3=Bell 4=Bar 5=Seven 6=Horseshoe
#constant BOARDX 224
#constant BOARDY 100

#constant ST_IDLE 0
#constant ST_FLASH 1
#constant ST_SETTLE 2
#constant ST_SWAPBACK 3
#constant ST_WIN 4
#constant ST_OVER 5

#constant KEY_ESC 27

// Text slots (text objects are created once, re-used every frame)
#constant T_TITLE 1
#constant T_SCORE_L 2
#constant T_SCORE_V 3
#constant T_TARGET_L 4
#constant T_TARGET_V 5
#constant T_MOVES_L 6
#constant T_MOVES_V 7
#constant T_COMBO_L 8
#constant T_COMBO_V 9
#constant T_END1 10
#constant T_END2 11
#constant T_END3 12
#constant T_HELP1 13
#constant T_HELP2 14
#constant T_HELP3 15
#constant T_RULE1 16
#constant T_RULE2 17
#constant T_RULE3 18
#constant TXT_SLOTS 18

// --- Globals (functions only see variables declared "global") ----------------
global gState as integer
global score as integer
global moves as integer
global target as integer
global combo as integer
global waitTimer as integer
global selC as integer
global selR as integer
global swapC1 as integer
global swapR1 as integer
global swapC2 as integer
global swapR2 as integer
global matchScore as integer
global jackpotSym as integer

// Board stored as flat arrays: index = column + row * COLS  (64 cells)
global dim grid[64] as integer     // 0 = empty, 1..NSYM = symbol
global dim mark[64] as integer     // 1 = part of a match
global dim offY[64] as float       // pixels a tile still has to fall (animation)

// Sprite ids for things that are shown/hidden
global endBoardBack as integer
global endPosterEdge as integer
global endPosterPaper as integer
global lastSpr as integer         // id of the sprite MakeBox created last

// ============================================================================
// SMALL HELPERS
// ============================================================================

function ClampC(v)
    if v < 0
        v = 0
    endif
    if v > 255
        v = 255
    endif
endfunction v

function MkCol(r, g, b)
    c = MakeColor(ClampC(r), ClampC(g), ClampC(b))
endfunction c

// align: 0=left, 1=center, 2=right
function Txt(slot, s$, x#, y#, size#, r, g, b, align)
    SetTextString(slot, s$)
    SetTextSize(slot, size#)
    SetTextAlignment(slot, align)
    SetTextPosition(slot, x#, y#)
    SetTextColor(slot, r, g, b, 255)
    SetTextVisible(slot, 1)
endfunction

function HideAllText()
    for i = 1 to TXT_SLOTS
        SetTextVisible(i, 0)
    next i
endfunction

// --- Draw-command wrappers (immediate mode, called every frame) ---------------
function GfxRect(x#, y#, w#, h#, r, g, b)
    c = MkCol(r, g, b)
    DrawBox(x#, y#, x# + w#, y# + h#, c, c, c, c, 1)
endfunction

function GfxOutline(x#, y#, w#, h#, r, g, b)
    c = MkCol(r, g, b)
    DrawBox(x#, y#, x# + w#, y# + h#, c, c, c, c, 0)
endfunction

function GfxEllipse(x#, y#, rx#, ry#, r, g, b)
    c = MkCol(r, g, b)
    DrawEllipse(x#, y#, rx#, ry#, c, c, 1)
endfunction

function GfxCircle(x#, y#, rad#, r, g, b)
    GfxEllipse(x#, y#, rad#, rad#, r, g, b)
endfunction

// 3-pixel-wide line
function GfxThick(x1#, y1#, x2#, y2#, r, g, b)
    c = MkCol(r, g, b)
    DrawLine(x1#, y1#, x2#, y2#, c, c)
    DrawLine(x1# + 1, y1#, x2# + 1, y2#, c, c)
    DrawLine(x1#, y1# + 1, x2#, y2# + 1, c, c)
endfunction

// Flat coloured box made from an image-less sprite (used for HUD panels, text
// goes on top of these). Nothing is loaded from disk.
function MakeBox(x#, y#, w#, h#, r, g, b, depth)
    spr = CreateSprite(0)
    SetSpriteSize(spr, w#, h#)
    SetSpritePosition(spr, x#, y#)
    SetSpriteColor(spr, r, g, b, 255)
    SetSpriteDepth(spr, depth)
    lastSpr = spr
endfunction

// Nailed wooden plank
function MakePlank(x#, y#, w#, h#)
    MakeBox(x#, y#, w#, h#, 60, 35, 15, 60)
    MakeBox(x# + 3, y# + 3, w# - 6, h# - 6, 135, 90, 45, 59)
    MakeBox(x# + 3, y# + h# / 2, w# - 6, 2, 110, 72, 35, 58)
    MakeBox(x# + 8, y# + 8, 5, 5, 200, 190, 160, 57)
    MakeBox(x# + w# - 13, y# + 8, 5, 5, 200, 190, 160, 57)
    MakeBox(x# + 8, y# + h# - 13, 5, 5, 200, 190, 160, 57)
    MakeBox(x# + w# - 13, y# + h# - 13, 5, 5, 200, 190, 160, 57)
endfunction

// ============================================================================
// SYMBOLS - every icon is drawn from primitives inside a 64x64 tile at x#,y#
// ============================================================================

function DrawCherry(x#, y#)
    cx# = x# + 32
    cy# = y# + 32
    // stems and leaf
    GfxThick(cx# - 10, cy# + 2, cx# + 3, cy# - 22, 90, 60, 30)
    GfxThick(cx# + 12, cy# + 4, cx# + 3, cy# - 22, 90, 60, 30)
    GfxEllipse(cx# + 11, cy# - 20, 9, 4, 50, 160, 60)
    // two cherries
    GfxCircle(cx# - 11, cy# + 11, 12, 150, 15, 30)
    GfxCircle(cx# - 11, cy# + 11, 10, 215, 35, 50)
    GfxCircle(cx# - 14, cy# + 8, 3, 255, 190, 190)
    GfxCircle(cx# + 12, cy# + 15, 12, 150, 15, 30)
    GfxCircle(cx# + 12, cy# + 15, 10, 215, 35, 50)
    GfxCircle(cx# + 9, cy# + 12, 3, 255, 190, 190)
endfunction

function DrawLemon(x#, y#)
    cx# = x# + 32
    cy# = y# + 32
    GfxEllipse(cx# - 23, cy#, 5, 4, 190, 155, 15)
    GfxEllipse(cx# + 23, cy#, 5, 4, 190, 155, 15)
    GfxEllipse(cx#, cy#, 23, 17, 190, 155, 15)
    GfxEllipse(cx#, cy#, 21, 15, 245, 215, 50)
    GfxEllipse(cx# - 5, cy# - 5, 9, 4, 255, 245, 150)
    GfxEllipse(cx# + 9, cy# - 17, 7, 3, 50, 160, 60)
endfunction

function DrawBell(x#, y#)
    cx# = x# + 32
    cy# = y# + 32
    GfxCircle(cx#, cy# - 23, 4, 190, 130, 20)
    // dome
    GfxEllipse(cx#, cy# - 6, 17, 18, 190, 130, 20)
    GfxEllipse(cx#, cy# - 6, 15, 16, 240, 185, 45)
    // body and flared rim
    GfxRect(cx# - 17, cy# - 6, 34, 16, 190, 130, 20)
    GfxRect(cx# - 15, cy# - 6, 30, 16, 240, 185, 45)
    GfxRect(cx# - 22, cy# + 8, 44, 7, 190, 130, 20)
    GfxRect(cx# - 20, cy# + 9, 40, 5, 240, 185, 45)
    // clapper and shine
    GfxCircle(cx#, cy# + 19, 5, 150, 95, 15)
    GfxThick(cx# - 8, cy# - 14, cx# - 10, cy# + 4, 255, 235, 150)
endfunction

function LetterB(x#, y0#, y1#)
    ym# = (y0# + y1#) / 2
    GfxThick(x#, y0#, x#, y1#, 255, 210, 60)
    GfxThick(x#, y0#, x# + 7, y0#, 255, 210, 60)
    GfxThick(x#, ym#, x# + 7, ym#, 255, 210, 60)
    GfxThick(x#, y1#, x# + 7, y1#, 255, 210, 60)
    GfxThick(x# + 8, y0# + 1, x# + 8, ym# - 1, 255, 210, 60)
    GfxThick(x# + 8, ym# + 1, x# + 8, y1# - 1, 255, 210, 60)
endfunction

function LetterA(x#, y0#, y1#)
    ym# = (y0# + y1#) / 2
    GfxThick(x#, y1#, x# + 4, y0#, 255, 210, 60)
    GfxThick(x# + 4, y0#, x# + 8, y1#, 255, 210, 60)
    GfxThick(x# + 2, ym# + 3, x# + 6, ym# + 3, 255, 210, 60)
endfunction

function LetterR(x#, y0#, y1#)
    ym# = (y0# + y1#) / 2
    GfxThick(x#, y0#, x#, y1#, 255, 210, 60)
    GfxThick(x#, y0#, x# + 7, y0#, 255, 210, 60)
    GfxThick(x#, ym#, x# + 7, ym#, 255, 210, 60)
    GfxThick(x# + 8, y0# + 1, x# + 8, ym# - 1, 255, 210, 60)
    GfxThick(x# + 3, ym#, x# + 8, y1#, 255, 210, 60)
endfunction

function DrawBar(x#, y#)
    cx# = x# + 32
    cy# = y# + 32
    GfxRect(cx# - 25, cy# - 15, 50, 30, 245, 245, 245)
    GfxRect(cx# - 23, cy# - 13, 46, 26, 25, 25, 30)
    LetterB(cx# - 17, cy# - 8, cy# + 8)
    LetterA(cx# - 4, cy# - 8, cy# + 8)
    LetterR(cx# + 9, cy# - 8, cy# + 8)
endfunction

function DrawSeven(x#, y#)
    cx# = x# + 32
    cy# = y# + 32
    c1 = MkCol(70, 10, 15)
    c2 = MkCol(215, 30, 40)
    // dark outline first
    GfxRect(cx# - 17, cy# - 23, 34, 12, 70, 10, 15)
    for k = -7 to 7
        DrawLine(cx# + 14 + k, cy# - 14, cx# - 6 + k, cy# + 23, c1, c1)
    next k
    // red fill
    GfxRect(cx# - 15, cy# - 21, 30, 8, 215, 30, 40)
    for k = -4 to 4
        DrawLine(cx# + 14 + k, cy# - 14, cx# - 6 + k, cy# + 23, c2, c2)
    next k
    // shine on the top bar
    GfxRect(cx# - 13, cy# - 20, 24, 2, 255, 140, 140)
endfunction

function DrawHorseshoe(x#, y#)
    cx# = x# + 32
    cy# = y# + 32
    // ring, then cut the top of the inside to make a "U"
    GfxEllipse(cx#, cy# + 2, 21, 23, 120, 125, 140)
    GfxEllipse(cx#, cy# + 2, 19, 21, 185, 190, 205)
    GfxEllipse(cx#, cy# + 2, 11, 13, 245, 232, 200)
    GfxRect(cx# - 11, cy# - 24, 22, 26, 245, 232, 200)
    // nail holes
    GfxCircle(cx# - 15, cy# - 6, 2.5, 80, 85, 100)
    GfxCircle(cx# - 16, cy# + 5, 2.5, 80, 85, 100)
    GfxCircle(cx# - 12, cy# + 16, 2.5, 80, 85, 100)
    GfxCircle(cx# + 15, cy# - 6, 2.5, 80, 85, 100)
    GfxCircle(cx# + 16, cy# + 5, 2.5, 80, 85, 100)
    GfxCircle(cx# + 12, cy# + 16, 2.5, 80, 85, 100)
endfunction

function DrawSymbol(s, x#, y#)
    if s = 1
        DrawCherry(x#, y#)
    elseif s = 2
        DrawLemon(x#, y#)
    elseif s = 3
        DrawBell(x#, y#)
    elseif s = 4
        DrawBar(x#, y#)
    elseif s = 5
        DrawSeven(x#, y#)
    elseif s = 6
        DrawHorseshoe(x#, y#)
    endif
endfunction

// ============================================================================
// BOARD LOGIC
// ============================================================================

function RunValue(length)
    if length >= 5
        exitfunction 150
    endif
    if length = 4
        exitfunction 60
    endif
endfunction 30

function RandSym()
    s = random(1, NSYM)
endfunction s

// Marks every run of 3+ (rows and columns). Returns the number of marked tiles
// and sets matchScore. A run of 5+ also marks every tile of that symbol.
function FindMatches()
    matchScore = 0
    jackpotSym = 0

    for i = 0 to 63
        mark[i] = 0
    next i

    // --- horizontal runs ---
    for r = 0 to ROWS - 1
        c = 0
        while c < COLS
            s = grid[c + r * COLS]
            runLen = 1
            if s <> 0
                while c + runLen < COLS
                    if grid[c + runLen + r * COLS] <> s
                        exit
                    endif
                    runLen = runLen + 1
                endwhile
                if runLen >= 3
                    for k = 0 to runLen - 1
                        mark[c + k + r * COLS] = 1
                    next k
                    matchScore = matchScore + RunValue(runLen)
                    if runLen >= 5
                        jackpotSym = s
                    endif
                endif
            endif
            c = c + runLen
        endwhile
    next r

    // --- vertical runs ---
    for c = 0 to COLS - 1
        r = 0
        while r < ROWS
            s = grid[c + r * COLS]
            runLen = 1
            if s <> 0
                while r + runLen < ROWS
                    if grid[c + (r + runLen) * COLS] <> s
                        exit
                    endif
                    runLen = runLen + 1
                endwhile
                if runLen >= 3
                    for k = 0 to runLen - 1
                        mark[c + (r + k) * COLS] = 1
                    next k
                    matchScore = matchScore + RunValue(runLen)
                    if runLen >= 5
                        jackpotSym = s
                    endif
                endif
            endif
            r = r + runLen
        endwhile
    next c

    // --- jackpot: clear every tile of the 5+ symbol ---
    if jackpotSym <> 0
        for i = 0 to 63
            if grid[i] = jackpotSym
                mark[i] = 1
            endif
        next i
        matchScore = matchScore + 200
    endif

    n = 0
    for i = 0 to 63
        n = n + mark[i]
    next i
endfunction n

function SwapTiles(c1, r1, c2, r2)
    t = grid[c1 + r1 * COLS]
    grid[c1 + r1 * COLS] = grid[c2 + r2 * COLS]
    grid[c2 + r2 * COLS] = t
endfunction

// 1 if any single swap would create a match
function HasMove()
    for r = 0 to ROWS - 1
        for c = 0 to COLS - 1
            if c < COLS - 1
                SwapTiles(c, r, c + 1, r)
                n = FindMatches()
                SwapTiles(c, r, c + 1, r)
                if n > 0
                    exitfunction 1
                endif
            endif
            if r < ROWS - 1
                SwapTiles(c, r, c, r + 1)
                n = FindMatches()
                SwapTiles(c, r, c, r + 1)
                if n > 0
                    exitfunction 1
                endif
            endif
        next c
    next r
endfunction 0

// Random board with no ready-made matches and at least one possible move
function FillBoard()
    ok = 0
    while ok = 0
        for i = 0 to 63
            grid[i] = RandSym()
            offY[i] = 0
        next i
        if FindMatches() = 0
            if HasMove() = 1
                ok = 1
            endif
        endif
    endwhile
endfunction

function ClearMarked()
    for i = 0 to 63
        if mark[i] = 1
            grid[i] = 0
        endif
    next i
endfunction

// Tiles fall into gaps (offY animates it), new random tiles fill the top
function DropTiles()
    for c = 0 to COLS - 1
        w = ROWS - 1
        for r = ROWS - 1 to 0 step -1
            if grid[c + r * COLS] <> 0
                if w <> r
                    grid[c + w * COLS] = grid[c + r * COLS]
                    grid[c + r * COLS] = 0
                    offY[c + w * COLS] = (w - r) * TILE
                endif
                w = w - 1
            endif
        next r
        for r = w to 0 step -1
            grid[c + r * COLS] = RandSym()
            offY[c + r * COLS] = 0
        next r
    next c
endfunction

function UpdateFalls()
    for i = 0 to 63
        if offY[i] > 0
            offY[i] = offY[i] - 12
            if offY[i] < 0
                offY[i] = 0
            endif
        endif
    next i
endfunction

function AnyFalling()
    for i = 0 to 63
        if offY[i] > 0
            exitfunction 1
        endif
    next i
endfunction 0

function InitGame()
    score = 0
    moves = 25
    target = 1500
    combo = 0
    selC = -1
    selR = -1
    gState = ST_IDLE
    FillBoard()
endfunction

// ============================================================================
// GAME UPDATE (state machine)
// ============================================================================

function TryClick()
    mx# = GetPointerX()
    my# = GetPointerY()

    if mx# < BOARDX or my# < BOARDY or mx# >= BOARDX + COLS * TILE or my# >= BOARDY + ROWS * TILE
        selC = -1
        exitfunction
    endif

    c = floor((mx# - BOARDX) / TILE)
    r = floor((my# - BOARDY) / TILE)

    if selC < 0
        selC = c
        selR = r
        exitfunction
    endif

    dc = c - selC
    dr = r - selR
    if dc < 0
        dc = -dc
    endif
    if dr < 0
        dr = -dr
    endif

    if dc + dr <> 1
        // not a neighbour: just move the selection
        selC = c
        selR = r
        exitfunction
    endif

    swapC1 = selC
    swapR1 = selR
    swapC2 = c
    swapR2 = r
    selC = -1
    selR = -1
    SwapTiles(swapC1, swapR1, swapC2, swapR2)

    if FindMatches() > 0
        moves = moves - 1
        combo = 1
        gState = ST_FLASH
        waitTimer = 18
    else
        gState = ST_SWAPBACK
        waitTimer = 12
    endif
endfunction

function UpdateGame()
    if gState = ST_IDLE
        if GetPointerPressed() = 1
            TryClick()
        endif

    elseif gState = ST_SWAPBACK
        waitTimer = waitTimer - 1
        if waitTimer <= 0
            SwapTiles(swapC1, swapR1, swapC2, swapR2)
            gState = ST_IDLE
        endif

    elseif gState = ST_FLASH
        waitTimer = waitTimer - 1
        if waitTimer <= 0
            score = score + matchScore * combo
            ClearMarked()
            DropTiles()
            gState = ST_SETTLE
            waitTimer = 6
        endif

    elseif gState = ST_SETTLE
        if AnyFalling() = 0
            waitTimer = waitTimer - 1
            if waitTimer <= 0
                if FindMatches() > 0
                    combo = combo + 1           // cascade!
                    gState = ST_FLASH
                    waitTimer = 18
                else
                    combo = 0
                    if score >= target
                        gState = ST_WIN
                    elseif moves <= 0
                        gState = ST_OVER
                    else
                        if HasMove() = 0
                            FillBoard()         // no moves left: reshuffle
                        endif
                        gState = ST_IDLE
                    endif
                endif
            endif
        endif

    else
        // win / game over: click to play again
        if GetPointerPressed() = 1
            InitGame()
        endif
    endif
endfunction

// ============================================================================
// DRAWING
// ============================================================================

function DrawBoard()
    // reel windows first
    for r = 0 to ROWS - 1
        for c = 0 to COLS - 1
            x# = BOARDX + c * TILE
            y# = BOARDY + r * TILE
            GfxRect(x#, y#, TILE, TILE, 70, 45, 25)
            GfxRect(x# + 2, y# + 2, TILE - 4, TILE - 4, 245, 232, 200)
        next c
    next r

    // matched tiles flash yellow
    if gState = ST_FLASH and mod(waitTimer, 6) < 3
        for r = 0 to ROWS - 1
            for c = 0 to COLS - 1
                if mark[c + r * COLS] = 1
                    GfxRect(BOARDX + c * TILE + 2, BOARDY + r * TILE + 2, TILE - 4, TILE - 4, 255, 255, 120)
                endif
            next c
        next r
    endif

    // symbols on top (falling ones are drawn offset upwards)
    for r = 0 to ROWS - 1
        for c = 0 to COLS - 1
            s = grid[c + r * COLS]
            hide = 0
            if gState = ST_FLASH and mark[c + r * COLS] = 1 and mod(waitTimer, 6) < 3
                hide = 1
            endif
            if s <> 0 and hide = 0
                DrawSymbol(s, BOARDX + c * TILE, BOARDY + r * TILE - offY[c + r * COLS])
            endif
        next c
    next r

    // selection frame
    if selC >= 0
        sx# = BOARDX + selC * TILE
        sy# = BOARDY + selR * TILE
        GfxOutline(sx#, sy#, TILE, TILE, 255, 215, 0)
        GfxOutline(sx# + 1, sy# + 1, TILE - 2, TILE - 2, 255, 215, 0)
        GfxOutline(sx# + 2, sy# + 2, TILE - 4, TILE - 4, 255, 215, 0)
    endif
endfunction

function DrawHud()
    Txt(T_TITLE, "SIX-SHOOTER REELS", 480, 14, 46, 255, 230, 140, 1)

    Txt(T_SCORE_L, "SCORE", 114, 120, 16, 245, 220, 150, 1)
    Txt(T_SCORE_V, str(score), 114, 148, 30, 255, 255, 255, 1)

    Txt(T_TARGET_L, "WANTED SCORE", 114, 225, 16, 245, 220, 150, 1)
    Txt(T_TARGET_V, str(target), 114, 253, 30, 255, 255, 255, 1)

    Txt(T_MOVES_L, "SHOTS LEFT", 846, 120, 16, 245, 220, 150, 1)
    Txt(T_MOVES_V, str(moves), 846, 148, 30, 255, 255, 255, 1)

    Txt(T_COMBO_L, "COMBO", 846, 225, 16, 245, 220, 150, 1)
    if combo > 1
        Txt(T_COMBO_V, "x" + str(combo), 846, 253, 30, 255, 220, 60, 1)
    else
        Txt(T_COMBO_V, "-", 846, 253, 30, 255, 255, 255, 1)
    endif

    Txt(T_HELP1, "Click a tile, then", 114, 335, 16, 240, 220, 170, 1)
    Txt(T_HELP2, "a neighbour to", 114, 357, 16, 240, 220, 170, 1)
    Txt(T_HELP3, "swap them.", 114, 379, 16, 240, 220, 170, 1)

    Txt(T_RULE1, "3 = 30   4 = 60", 846, 335, 16, 240, 220, 170, 1)
    Txt(T_RULE2, "5+ = JACKPOT:", 846, 357, 16, 255, 220, 60, 1)
    Txt(T_RULE3, "clears that symbol", 846, 379, 16, 255, 220, 60, 1)
endfunction

function DrawGame()
    ShowEnd = 0
    if gState = ST_WIN or gState = ST_OVER
        ShowEnd = 1
    endif

    SetSpriteVisible(endBoardBack, ShowEnd)
    SetSpriteVisible(endPosterEdge, ShowEnd)
    SetSpriteVisible(endPosterPaper, ShowEnd)

    // Board and symbols are draw commands (they render on top of sprites), so
    // they are skipped while the end-of-round poster is on screen.
    if ShowEnd = 0
        DrawBoard()
    else
        if gState = ST_WIN
            Txt(T_END1, "HOWDY, SHERIFF! YOU WIN", 480, 262, 26, 90, 40, 10, 1)
        else
            Txt(T_END1, "OUT OF BULLETS - GAME OVER", 480, 262, 26, 140, 20, 20, 1)
        endif
        Txt(T_END2, "Final score: " + str(score), 480, 316, 22, 60, 35, 15, 1)
        Txt(T_END3, "Click to ride again", 480, 360, 18, 60, 35, 15, 1)
    endif

    DrawHud()
endfunction

// ============================================================================
// ONE-TIME SETUP: text objects and static HUD pieces (blank coloured sprites)
// ============================================================================

for i = 1 to TXT_SLOTS
    CreateText(i, "")
    SetTextSize(i, 18)
    SetTextDepth(i, 5)
    SetTextVisible(i, 0)
next i

// Saloon-wall stripes in the side margins (never behind the board)
for i = 0 to 10
    MakeBox(0, 90 + i * 54, 208, 3, 90, 55, 28, 90)
    MakeBox(752, 90 + i * 54, 208, 3, 90, 55, 28, 90)
next i

// Title banner
MakeBox(0, 0, 960, 78, 60, 35, 15, 60)
MakeBox(0, 6, 960, 66, 150, 100, 50, 59)
MakeBox(0, 72, 960, 6, 200, 160, 60, 58)

// HUD planks
MakePlank(24, 110, 180, 90)
MakePlank(24, 215, 180, 90)
MakePlank(756, 110, 180, 90)
MakePlank(756, 215, 180, 90)

// Board frame: four gold strips and four dark strips AROUND the board only
bw = COLS * TILE
bh = ROWS * TILE
MakeBox(BOARDX - 14, BOARDY - 14, bw + 28, 14, 200, 160, 60, 60)
MakeBox(BOARDX - 14, BOARDY + bh, bw + 28, 14, 200, 160, 60, 60)
MakeBox(BOARDX - 14, BOARDY, 14, bh, 200, 160, 60, 60)
MakeBox(BOARDX + bw, BOARDY, 14, bh, 200, 160, 60, 60)
MakeBox(BOARDX - 8, BOARDY - 8, bw + 16, 8, 60, 35, 15, 59)
MakeBox(BOARDX - 8, BOARDY + bh, bw + 16, 8, 60, 35, 15, 59)
MakeBox(BOARDX - 8, BOARDY, 8, bh, 60, 35, 15, 59)
MakeBox(BOARDX + bw, BOARDY, 8, bh, 60, 35, 15, 59)

// End-of-round poster (hidden until the round ends)
MakeBox(BOARDX, BOARDY, bw, bh, 70, 45, 25, 80)
endBoardBack = lastSpr
MakeBox(280, 230, 400, 180, 60, 35, 15, 30)
endPosterEdge = lastSpr
MakeBox(286, 236, 388, 168, 235, 220, 175, 29)
endPosterPaper = lastSpr
SetSpriteVisible(endBoardBack, 0)
SetSpriteVisible(endPosterEdge, 0)
SetSpriteVisible(endPosterPaper, 0)

// ============================================================================
// MAIN LOOP
// ============================================================================

InitGame()

while GetRawKeyState(KEY_ESC) = 0
    HideAllText()
    UpdateFalls()
    UpdateGame()
    DrawGame()
    Sync()
endwhile

end
