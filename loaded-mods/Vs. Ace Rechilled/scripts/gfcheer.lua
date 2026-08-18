local hitCombo = 0

function goodNoteHit(id, direction, noteType, isSustainNote)
    if not isSustainNote then
        hitCombo = (hitCombo + 1)
    end
    if hitCombo == 50 then
        triggerEvent('Play Animation', 'cheer', 'gf');
    end
end

function noteMiss(id, direction, noteType, isSustainNote)
    if getProperty('songMisses')+ 1 then
        hitCombo = 0
    end
end