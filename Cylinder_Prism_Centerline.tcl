#################################################################
# File      : CCB_AUTO_MIG_Ver1.tcl
# Date      : 2018.01.29
# Created by: HXM
# Purpose   : 1.根据MIG几何生成MIG Connector
#             2.MIG几何主要为圆柱和棱柱
#################################################################
catch {namespace delete ::MIGCreate::}
namespace eval ::MIGCreate:: {
	variable mig_meta; #MIG焊的DB_PART_NAME,不支持通配符号
	set mig_meta "WELD POINTS";
	
	variable mig_part_name; #MIG焊的Part Name,支持通配符号
	set mig_part_name "WELD POINTS";

	variable baseDir;#当前程序运行目录
	set baseDir [file dir [info script]]; #获得当前程序运行目录
	
	variable curProfile;#当前求解器模板
	set curProfile [lindex [hm_framework getuserprofile] 0]
}

###############################################################
## 删除原有connector
###############################################################
proc ::MIGCreate::ClearConnector {} {
	
	*CE_GlobalSetInt "g_ce_spotvis" 0
	*CE_GlobalSetInt "g_ce_seamvis" 1
	*CE_GlobalSetInt "g_ce_areavis" 0
	*CE_GlobalSetInt "g_ce_boltvis" 0
	*CE_GlobalSetInt "g_ce_applymassvis" 0
	*plot
	
	*createmark connectors 1 "displayed"
	if {[llength [hm_getmark connectors 1]]>0} {
		set answer [tk_messageBox -title "MIG Create" \
		-message "All existing Connectors will be deleted. Click OK to continue, Click Cancel to Quit" \
		-type okcancel]
		switch -- $answer {
			cancel {
				return -code error "Exsiting Seam Connector Not Deleted"
			}
			ok {
				*CE_FE_GlobalFlags 1 0
				*deletemark connectors 1
			}
		}
	}
	*CE_GlobalSetInt "g_ce_spotvis" 1
	*CE_GlobalSetInt "g_ce_seamvis" 1
	*CE_GlobalSetInt "g_ce_areavis" 1
	*CE_GlobalSetInt "g_ce_boltvis" 1
	*CE_GlobalSetInt "g_ce_applymassvis" 1
	*plot
}

###############################################################
## 根据Metadata选择comp并返回Solid List
###############################################################
proc ::MIGCreate::GetSolidListbyMeta {meta} {
	#arg: meta  DB_PART_NAME名称,精确匹配不支持通配符
	set mig_comp_list "";
	
	*createmark comps 1 "by metadata equal to value" "DB_PART_NAME" $meta
	set mig_comp_list [hm_getmark comps 1]
	eval *createmark solids 1 "by comp id" $mig_comp_list
	set solid_list [hm_getmark solids 1]
	return $solid_list
}

###############################################################
## 根据PartName选择comp并返回Solid List
###############################################################
proc ::MIGCreate::GetSolidListbyPartname {partname} {
	#arg: partname part名称,支持通配符
	*createmark modules 1 "all"
	set part_id_list [hm_getmark modules 1]
	set mig_comp_list "";
	foreach id $part_id_list {
		set tmpname [hm_getvalue modules id=$id dataname=name]
		if {[string match $partname $tmpname]==1} {
			lappend mig_comp_list [hm_getvalue modules id=$id dataname=HW_CID]
		} else {
			continue
		}
	}
	eval *createmark solids 1 "by comp id" $mig_comp_list
	set solid_list [hm_getmark solids 1]
	return $solid_list
}

###############################################################
## 手工选择Solid List
###############################################################
proc ::MIGCreate::GetSolidListbySelect {} {
	
	set solid_list "";
	
	*createmarkpanel solids 1 "Select MIG SOLIDS"
	set solid_list [hm_getmark solids 1]
	return $solid_list
}

###############################################################
## 获取需要处理的Solid list
###############################################################
proc ::MIGCreate::GetSolidList {} {
	variable mig_meta;
	variable mig_part_name;
	
	set solid_list "";
	
	set solid_list_bymeta "";
	set solid_list_bymeta [::MIGCreate::GetSolidListbyMeta $mig_meta]
	
	set solid_list_bypart "";
	set solid_list_bypart [::MIGCreate::GetSolidListbyPartname $mig_part_name]
	
	if {[llength $solid_list_bymeta]==0&&[llength $solid_list_bypart]==0} {
		tk_messageBox -title "MIG Create" \
		-message "No Solids Found by Metadata and Part Name, Please select MIG Solids Manually"
		set solid_list [::MIGCreate::GetSolidListbySelect]
	} elseif {[llength $solid_list_bymeta]!=0&&[llength $solid_list_bypart]==0} {
		set solid_list $solid_list_bymeta
		eval *createmark solids 1 $solid_list
		*editmarkpanel solids 1 "Select the MIG Solids"
		set solid_list [hm_getmark solids 1]
		return $solid_list
	} elseif {[llength $solid_list_bymeta]==0&&[llength $solid_list_bypart]!=0} {
		set solid_list $solid_list_bypart
		eval *createmark solids 1 $solid_list
		*editmarkpanel solids 1 "Select the MIG Solids"
		set solid_list [hm_getmark solids 1]
		return $solid_list
	} elseif {[llength $solid_list_bymeta]!=0&&[llength $solid_list_bypart]!=0} {
		set solid_list $solid_list_bypart
		eval *createmark solids 1 $solid_list
		*editmarkpanel solids 1 "Select the MIG Solids"
		set solid_list [hm_getmark solids 1]
		return $solid_list
	} else {
		return code -error "can not judge"
	}
}

###############################################################
## Remove specific elements from list
## to_del 
###############################################################
proc ::MIGCreate::RemoveElementsfromList {to_del orig_list} {
    #arg: to_del list of elements to be deleted
    #arg: orig_list  orig_list to delete from
    #output: return modified list
    set tmp $orig_list
    foreach item $to_del {
        set idx [lsearch -exact $tmp $item]
        if {$idx==-1} {
            #puts "element not found."
        } else {
            set tmp [lreplace $tmp $idx $idx]  
        } 
    }
    return $tmp
}
###############################################################
## 根据solidid,设置solid所在comp为当前comp
###############################################################
proc ::MIGCreate::CurrentCompbySoildid {solidid} {
	#arg: solidid 实体编号
	set compname [hm_getvalue solids id=$solidid dataname=collector.name]
	*currentcollector comps $compname
}
###############################################################
## 逐步增加suppress容差,直到实体拥有n个面
###############################################################
proc ::MIGCreate::EdgeSuppress {solidid start_angle surf_num} {
	#arg: solidid 实体编号
	#arg: start_angle 起始supress特征角度
	#arg: surf_num 希望的面的数量
	set angle $start_angle;
	while {$angle<90} {
		*createmark lines 1 "by solids" $solidid
		*edgesmarksuppress 1 $angle
		*createmark surfs 1 "by solids" $solidid
		set surfid [hm_getmark surfs 1]
		if {[llength $surfid]==$surf_num} {
			puts "Solid $solidid: Surfs number is $surf_num"
			break
		} else {
			puts "Suppressed using $angle"
			set angle [expr $angle+10]
		}
	}
}
###############################################################
## 按边的数量分类实体的面
###############################################################
proc ::MIGCreate::ClassifybyEdgeNumber {solidid edge_num} {
	#arg: solidid 实体编号
	#arg: edge_num 希望的面的数量
	*createmark surfs 1 "by solids" $solidid
	set surfid [hm_getmark surfs 1]
	set surf_list "";
	foreach id $surfid {
		set num [lindex [hm_getsurfaceedges $id] 0]
		if {[llength $num]==$edge_num} {
			lappend surf_list $id
		} else {
			continue
		}
	}
	return $surf_list
}

###############################################################
## 返回圆柱去掉端面后的面数量
###############################################################
proc ::MIGCreate::ExcludeEndSurf {solidid end_surf} {
	#arg: solidid 圆柱体编号
	#arg: end_surf 端面列表
	*createmark surfs 1 "by solids" $solidid
	set surfid [hm_getmark surfs 1]
	set surf_list [::MIGCreate::RemoveElementsfromList $end_surf $surfid]
	return $surf_list
}

###############################################################
## 按面积排序面,从大到小,返回排序后的surf列表
###############################################################
proc ::MIGCreate::SortbyArea {surf_list} {
	#arg: surf_list 需要排序的面列表
	set area_list "";
	variable tmp;
	array unset tmp;
	foreach id $surf_list {
		set area [hm_getareaofsurface surfs $id]
		lappend area_list $area
		set tmp($area) $id
	}
	set area_list [lsort -decreasing -real $area_list]
	set sorted "";
	foreach item $area_list {
		lappend sorted $tmp($item) 
	}
	return $sorted
}
###############################################################
## 获取面的边缘
###############################################################
proc ::MIGCreate::GetEdgeList {surf_list} {
	#arg: surf_list 需要获取边缘的面列表
	set edge_list "";
	foreach surf $surf_list {
		set tmp [lindex [hm_getsurfaceedges $surf] 0]
		foreach id $tmp {
			lappend edge_list $id
		}
	}
	return $edge_list
}

###############################################################
## 选择需要处理的切割圆柱实体零件,并生成中心线
###############################################################
proc ::MIGCreate::CreatePrismCenterLine {solidid {surf_num 5} {end_edge_num 3} {side_edge_num 4}} { 
	#arg: solidid 实体编号
	#arg: end_edge_num 端部边线数量
	#arg: side_edge_num 侧面边线数量
	
	::MIGCreate::CurrentCompbySoildid $solidid
	::MIGCreate::EdgeSuppress $solidid 30 $surf_num
	
	set prism_end_surf [::MIGCreate::ClassifybyEdgeNumber $solidid $end_edge_num]
	
	set prism_side_surf [::MIGCreate::ClassifybyEdgeNumber $solidid $side_edge_num]
	
	set prism_side_surf [::MIGCreate::SortbyArea $prism_side_surf]
	
	set end_edge_list [::MIGCreate::GetEdgeList $prism_end_surf]
	set side_max_edge_list [::MIGCreate::GetEdgeList [lindex $prism_side_surf 0]]
	set side_min_edge_list [::MIGCreate::GetEdgeList [lindex $prism_side_surf end]]
	
	set connectorline "";
	set connectorline [::MIGCreate::RemoveElementsfromList $end_edge_list $side_min_edge_list]
	set connectorline [::MIGCreate::RemoveElementsfromList $side_max_edge_list $connectorline]
	
	if {[llength $connectorline]==1} {
		return $connectorline
	} else {
		return -code error "Solid $solidid: connectorline number not equal to 1"
	}
}

###############################################################
## suppress edge by length
###############################################################
proc ::MIGCreate::EdgeSuppressbyLength {surf_list line_length} {
	#arg: surf_list 面列表
	#arg: line_length 线长度
	set edge_list "";
	foreach surf $surf_list {
		set tmp [lindex [hm_getsurfaceedges $surf] 0]
		foreach id $tmp {
			lappend edge_list $id
		}
	}
	set circle "";
	foreach edge $edge_list {
		set length [hm_linelength $edge]
		if {$length<=[expr $line_length+0.1]&&$length>=[expr $line_length-0.1]} {
			lappend circle $edge
		}
	}
	eval *createmark lines 1 $circle
	*edgesmarksuppress 1 80
}
###############################################################
## 移动边缘线至中间
###############################################################
proc ::MIGCreate::MoveCylinderLine {end_line side_line} {
	#arg: end_line 端部线
	#arg: side_line 侧面线
	
	*createmark lines 1 $end_line
	*createbestcirclecenternode lines 1 0 1 0
	*createmark nodes 1 -1
	set center [hm_getmark nodes 1]
	
	*createdoublearray 1 1
	*nodecreateatlineparams $end_line 1 1 0 0 0
	*createmark nodes 1 -1
	set edge [hm_getmark nodes 1]
	#对所有直线进行操作
	*createmark lines 1 $side_line
	*duplicatemark lines 1 0
	*createmark lines 1 -1
	set connectorline [hm_getmark lines 1]
	
	*createmark lines 1 $connectorline
	
	set mag [lindex [hm_getdistance nodes $edge $center 0] 0]
	set vector_x [lindex [hm_getdistance nodes $edge $center 0] 1]
	set vector_y [lindex [hm_getdistance nodes $edge $center 0] 2]
	set vector_z [lindex [hm_getdistance nodes $edge $center 0] 3]
		
	*createvector 1 $vector_x $vector_y $vector_z
	*translatemark lines 1 1 $mag
	*nodecleartempmark
	return $connectorline
}

###############################################################
## 选择需要处理的圆柱实体零件,并生成中心线, 适用于圆柱只有1条侧边的情况
###############################################################
proc ::MIGCreate::CreateCylinderCenterLineType1 {solidid {surf_num 3} {end_edge_num 1} {side_edge_num 4}} { 
	#arg: solidid 实体编号
	#arg: surf_num  标准情况面的数量
	#arg: end_edge_num 端部边线数量
	#arg: side_edge_num 侧面边线数量
	
	::MIGCreate::CurrentCompbySoildid $solidid
	
	set cylinder_end_surf [::MIGCreate::ClassifybyEdgeNumber $solidid $end_edge_num]
	set cylinder_side_surf [::MIGCreate::ExcludeEndSurf $solidid $cylinder_end_surf]
	if {[llength $cylinder_side_surf]>[expr $surf_num-2]} {
		set end_length [hm_linelength [::MIGCreate::GetEdgeList [lindex $cylinder_end_surf 0]]]
		::MIGCreate::EdgeSuppressbyLength $cylinder_side_surf $end_length
		set cylinder_side_surf [::MIGCreate::ExcludeEndSurf $solidid $cylinder_end_surf]
	} elseif {[llength $cylinder_side_surf]==[expr $surf_num-2]} {
		puts "Solid Cylinder $solidid, Side Surf $cylinder_side_surf found"
	} else {
		return -code error "Cyliner Side Surf not found"
	}
	
	set cylinder_end_edge [::MIGCreate::GetEdgeList $cylinder_end_surf]
	set cylinder_side_edge [::MIGCreate::GetEdgeList $cylinder_side_surf]
	set side_edge_to_move [::MIGCreate::RemoveElementsfromList $cylinder_end_edge $cylinder_side_edge]
	set connectorline [::MIGCreate::MoveCylinderLine [lindex $cylinder_end_edge 0] $side_edge_to_move]

	if {[llength $connectorline]==1} {
		return $connectorline
	} else {
		return -code error "Solid $solidid: connectorline number not equal to 1"
	}
}

###############################################################
## 生成midline
###############################################################
proc ::MIGCreate::CreateMidLine {line1 line2} {
	#arg: line1 第一条线
	#arg: line2 第二条线
	*createlist lines 1 $line1
	*createlist nodes 1
	*createlist lines 2 $line2
	*createlist nodes 2
	*linescreatemidline 1 1 2 2
	*createmark lines 1 -1
	set id [hm_getmark lines 1]
	return $id
}

###############################################################
## 选择需要处理的圆柱实体零件,并生成中心线, 适用于圆柱有2条侧边的情况
###############################################################
proc ::MIGCreate::CreateCylinderCenterLineType2 {solidid {surf_num 4} {end_edge_num 2}} {
	#arg: solidid 实体编号
	#arg: surf_num  标准情况面的数量
	#arg: end_edge_num 端部边线数量
	::MIGCreate::CurrentCompbySoildid $solidid
	set cylinder_end_surf [::MIGCreate::ClassifybyEdgeNumber $solidid $end_edge_num]
	set cylinder_side_surf [::MIGCreate::ExcludeEndSurf $solidid $cylinder_end_surf]
	if {[llength $cylinder_side_surf]!=[expr $surf_num-2]} {
		set tmp_edge [::MIGCreate::GetEdgeList [lindex $cylinder_end_surf 0]]
		set tmp_edge [lindex $tmp_edge 0]
		set end_length [hm_linelength $tmp_edge]
		::MIGCreate::EdgeSuppressbyLength $cylinder_side_surf $end_length
		set cylinder_side_surf [::MIGCreate::ExcludeEndSurf $solidid $cylinder_end_surf]
	} elseif {[llength $cylinder_side_surf]==[expr $surf_num-2]} {
		puts "Solid Cylinder $solidid, Side Surf $cylinder_side_surf found"
	} else {
		return -code error "Cyliner Side Surf not found"
	}
	set cylinder_end_edge [::MIGCreate::GetEdgeList $cylinder_end_surf]
	set cylinder_side_edge [::MIGCreate::GetEdgeList $cylinder_side_surf]
	
	set side_edge_to_mid [::MIGCreate::RemoveElementsfromList $cylinder_end_edge $cylinder_side_edge]
	puts $side_edge_to_mid
	set side_edge_to_mid [lsort -decreasing $side_edge_to_mid]
	
	set connectorline [::MIGCreate::CreateMidLine [lindex $side_edge_to_mid 0] [lindex $side_edge_to_mid end]]
	
	if {[llength $connectorline]==1} {
		return $connectorline
	} else {
		return -code error "Solid $solidid: connectorline number not equal to 1"
	}
}
###############################################################
## 根据中心线,建立connector并realize
###############################################################
proc ::MIGCreate::CreateRealizeConnector {solver lineid} {
	#arg: solver 当前模板
	#arg: lineid 需要处理的线编号
	
	*createlist lines 1 $lineid
	*createmark components 2 "all"	
	*createstringarray 14 "link_elems_geom=elems" "link_rule=now" "relink_rule=none" \
	"tol_flag=1" "tol=5.000000" "line_spacing=5.000000" "line_density=0" "seam_area_group=2" \
	"ce_fe_height=5.000000" "ce_fe_capangle=65.000000" "ce_fe_runoffangle=10.000000" \
	"ce_fe_sharpcorner=0" "ce_extralinknum=0" "ce_hexaoffsetcheck=1"
	*CE_ConnectorCreateByMark lines 1 "seam" 2 components 2 1 14
	*createmark connectors 1 -1
	set compname [hm_getvalue lines id=$lineid dataname=collector.name]
	*currentcollector comps $compname
	switch $solver {
		OptiStruct {
			*createstringarray 21 "ce_fevectorreverse=0" "ce_fedepth=1.000000" "ce_fe_offsetangle=45.000000" \
			"ce_fe_thck_flag=1" "ce_fe_density=1" "ce_fe_strips=1" "ce_fe_rows=1" "ce_fe_const_height=0.000000" \
			"ce_fe_maint_gaps=0.000000" "ce_nonnormal=1" "ce_connectivity=4" "ce_dir_assign=0" \
			"ce_prop_opt=1" "ce_propertyid=0" "ce_fe_height=5.000000" "ce_fe_capangle=65.000000" \
			"ce_fe_runoffangle=10.000000" "ce_fe_sharpcorner=0" "ce_reapplylinknum=0" \
			"ce_extralinknum=0" "ce_hexaoffsetcheck=1"
			*CE_FE_RealizeWithDetails 1 "seam" "optistruct" 5 0 1 5 1 21
		}
		#Abaqus {
		#	*createstringarray 9 "ce_nonnormal=1" "ce_systems=0" "ce_connectivity=0" "ce_dir_assign=0" \
		#	"ce_prop_opt=2" "ce_areathicknesstype=1" "ce_areastacksize=1" \
		#	"ce_propertyscript=$baseDir/Abaqus_Adhesive_PostProcess.tcl" "ce_hexaoffsetcheck=1"
		#	*CE_FE_RealizeWithDetails 1 "area" "abaqus" 1001 9 1 20 1 9
		#}
	}
}

###############################################################
## 对于圆柱型零件的main,Type1:适用于圆柱只有1条侧边的情况
###############################################################
proc ::MIGCreate::CylinderType1Main {} {
	variable mig_meta; #MIG焊的DB_PART_NAME,不支持通配符号
	variable mig_part_name; #MIG焊的Part Name,支持通配符号
	variable curProfile;#当前求解器模板
	
	::MIGCreate::ClearConnector
	set solid_list [::MIGCreate::GetSolidList]
	foreach item $solid_list {
		set connectorline [::MIGCreate::CreateCylinderCenterLineType1 $item]
		::MIGCreate::CreateRealizeConnector $curProfile $connectorline
	}
}
#::MIGCreate::CylinderType1Main
###############################################################
## 对于圆柱型零件的main,Type2:适用于圆柱有2条侧边的情况
###############################################################
proc ::MIGCreate::CylinderType2Main {} {
	variable mig_meta; #MIG焊的DB_PART_NAME,不支持通配符号
	variable mig_part_name; #MIG焊的Part Name,支持通配符号
	variable curProfile;#当前求解器模板
	
	::MIGCreate::ClearConnector
	set solid_list [::MIGCreate::GetSolidList]
	foreach item $solid_list {
		set connectorline [::MIGCreate::CreateCylinderCenterLineType2 $item]
		::MIGCreate::CreateRealizeConnector $curProfile $connectorline
	}
}
#::MIGCreate::CylinderType2Main
###############################################################
## 对于Prism型零件的main
###############################################################
proc ::MIGCreate::PrismMain {} {
	variable mig_meta; #MIG焊的DB_PART_NAME,不支持通配符号
	variable mig_part_name; #MIG焊的Part Name,支持通配符号
	variable curProfile;#当前求解器模板
	
	::MIGCreate::ClearConnector
	set solid_list [::MIGCreate::GetSolidList]
	foreach item $solid_list {
		set connectorline [::MIGCreate::CreatePrismCenterLine $item]
		::MIGCreate::CreateRealizeConnector $curProfile $connectorline
	}
}
#::MIGCreate::PrismMain





















