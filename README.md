# TPWL_WORKFLOW
matlab version of POD-TPWL, including rate control and geo-paramter control	\
Reference: \
Jin, Z. L., & Durlofsky, L. J. (2018). Reduced-order modeling of CO 2 storage operations. International Journal of Greenhouse Gas Control, 68, 49-67. \
Jin, L. Z. (2015). Application of Reduced-Order Modeling for Geological Carbon Sequestration (Master thesis, Stanford University). \
Mishra, S., Ganesh, P. R., Schuetter, J., He, J., Jin, Z., & Durlofsky, L. J. (2015). SPE-175097-MS. \


# MATALB version of POD-TPWL
Modified specifically for geo-mechanics purpose \
LARRY JIN, Stanford University, 2017

Master functions	\
			main.m 				: for basic pod-tpwl functionalities \
			pod_tpwl_workflow.m 		: used in optimization, called by nomad_opt.m in NOMAD_OPT folder	

Workflow functions	\
			pod_geomech.m			:	\
			tpwl.m				:	\
			read_hdf_geomech.m		:	\
			read_jacobi_geomech.m		:	\
			input_adgprs.m			:	\
			run_adgprs.m			:	\
			response_adgprs.m		:	\
			plot_time_series.m		:	

Support functions	\
			obj_evaluation.m		: called by pod_tpwl_workflow.m in optimization	\
			gen_well_schedule.m		: called in optimization	\
			gen_well_param.m		: called in workflow (pod_tpwl_workflow.m) in optimization	\
			point_selection.m		: called by tpwl.m	

Utility functions (standalone)	\
			auto_comp.m			:	\
			case_input.m			:	\
			plot_color_map_geomech.m	:	\
			plot_opt.m 			:	\
			plot_well_ctrl.m		:	\
			plot_target_function.m 		:	\
			standalone_flash_parallel.m	:	\
			standalone_read_hdf.m 		:	\
			standalone_read_jacobi.m	:	\
			standalone_target_function.m	:	\
			standalone_gen_well_schedule.m  :	\
			standalone_plot_time_series.m	:	

Util class (utility functions, Util.m)
			load_multi_field 		: called by plot_opt.m, plot_well_ctrl.m	\
			schedule_convert		: called a few times by Workflow functions (tpwl.m, flash_parallel.m)	\
			load_field_to_struct 		:	\
			table_interpolation		: called by bo_well_response.m (not used now)	

Legacy Functions	\
			bo_well_response.m		: replaced by response_adgprs.m	\
			flash_parallel.m		: replaced by response_adgprs.m	

---------------------------------------------------------------------------------------
Parameters to be tuned within functions:	\
main.m	\
			wf_switchs	\
			params	\
point_selection.m	\
			method	\

All the standalone functions	\
