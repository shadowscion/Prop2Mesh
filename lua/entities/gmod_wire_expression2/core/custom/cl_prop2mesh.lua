E2Helper.Descriptions["p2mCreate(va)"] = ""
E2Helper.Descriptions["p2mHideModel(e:n)"] = ""
E2Helper.Descriptions["p2mSetAng(e:a)"] = ""
E2Helper.Descriptions["p2mSetColor(e:v)"] = ""
E2Helper.Descriptions["p2mSetColor(e:xv4)"] = ""

local example = [[
Table of subtables, required fields (pos=v,ang=a,mdl=s) and optional fields (clips=r[v4],scale=v)
Example:
ENT:p2mSetData(table(
    table("mdl" = "models/props_borealis/bluebarrel001.mdl","pos" = vec(50,0,0),"ang" = ang(),"clips" = array(vec4(1,0,0,15))),
    table("mdl" = "models/props_borealis/bluebarrel001.mdl","pos" = vec(0,50,0),"ang" = ang(),"clips" = array(vec4(0,0,1,5)))
))]]

E2Helper.Descriptions["p2mSetData(e:t)"] = example

E2Helper.Descriptions["p2mSetMaterial(e:s)"] = ""
E2Helper.Descriptions["p2mSetParent(e:e)"] = ""
E2Helper.Descriptions["p2mSetPos(e:v)"] = ""
E2Helper.Descriptions["p2mSetRenderBounds(e:vv)"] = ""
