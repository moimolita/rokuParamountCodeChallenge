' ─── Pure helper utilities (global) ──────────────────────────────────────────
' Dependency-free functions reusable by any component (no m. access). Each consuming
' component must declare this script in its XML.

'**
'* @description Rewrites an OMDb/Amazon poster URL to request a specific width from
'*              the source (not just rescale). OMDb posters end in a size/crop token
'*              chain after "._V1_"; rewriting a single token can leave others
'*              inconsistent (distorted image), so we truncate after "._V1_" and
'*              rebuild with one clean "_SX{width}.jpg". Falls back to the original
'*              URL if "._V1_" is absent; "N/A"/empty → "".
'* @param {String} originalUrl The poster URL from OMDb.
'* @param {Integer} width Desired image width in pixels (e.g. 200 grid, 500 details).
'* @returns {String} The rebuilt URL, or "" if unusable, or the original as fallback.
'*
function buildPosterUrl(originalUrl as string, width as integer) as string
    if originalUrl = "" or originalUrl = "N/A" then return ""

    marker = "._V1_"
    markerPos = instr(1, originalUrl, marker)

    ' No recognizable base marker — return as-is (safe fallback).
    if markerPos = 0 then return originalUrl

    ' Keep everything up to and including "._V1_", then append one clean size token.
    ' SX = scale by width, preserving aspect ratio. Drops crop/quality tokens that
    ' would otherwise conflict with the new width.
    base = left(originalUrl, markerPos + len(marker) - 1)
    return base + "SX" + width.toStr() + ".jpg"
end function
