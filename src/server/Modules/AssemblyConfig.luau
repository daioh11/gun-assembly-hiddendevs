-- every tunable value lives here
return table.freeze({ --table.freeze makes table read only
    --tags for collection service
	PartTag = "GunPart", 
	ComponentAttribute = "ComponentType", -- attribute must match for part and slot

	SnapRadius = 3, 
	SnapHeight = 1.5,
	SnapTime = 1, 

	StoreName = "GunAssemblyRecords",
})