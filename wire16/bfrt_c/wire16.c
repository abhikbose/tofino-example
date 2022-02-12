#define BFRT_GENERIC_FLAGS
#include "common.h"

#include <bfsys/bf_sal/bf_sys_intf.h>
#include <bf_rt/bf_rt.h>

// Key field ids, table data field ids, action ids, Table hdl required for
// interacting with the table
const bf_rt_info_hdl *bfrtInfo = NULL;
const bf_rt_table_hdl *tblForward = NULL;
bf_rt_session_hdl *session = NULL;

bf_rt_table_key_hdl *bfrtTableKey;
bf_rt_table_data_hdl *bfrtTableData;

// Key field ids
bf_rt_id_t tblForward_ingressPort = 0;

// Action Ids
bf_rt_id_t tblForward_forward_action_id = 0;
// bf_rt_id_t tblForward_nop_action_id = 0;

// Data field Ids for route action
bf_rt_id_t tblForward_forward_action_dstPort = 0;



#define ALL_PIPES 0xffff
bf_rt_target_t dev_tgt;

bool interactive = true;

// This function does the initial setUp of getting bfrtInfo object associated
// with the P4 program from which all other required objects are obtained
void setUp() {
  dev_tgt.dev_id = 0;
  dev_tgt.pipe_id = ALL_PIPES;

  // Get bfrtInfo object from dev_id and p4 program name
  bf_status_t bf_status =
      bf_rt_info_get(dev_tgt.dev_id, "wire16", &bfrtInfo);
  // Check for status
  bf_sys_assert(bf_status == BF_SUCCESS);

  // Create a session object
  bf_status = bf_rt_session_create(&session);
  // Check for status
  bf_sys_assert(bf_status == BF_SUCCESS);
}

// This function does the initial set up of getting key field-ids, action-ids
// and data field ids associated with the ipRoute table. This is done once
// during init time.
void tableSetUp() {
  // Get table object from name
  bf_status_t bf_status = bf_rt_table_from_name_get(
      bfrtInfo, "SwitchIngress.tbl_forward", &tblForward);
  bf_sys_assert(bf_status == BF_SUCCESS);

  // Get action Ids for forward and nop actions
  bf_status = bf_rt_action_name_to_id(
      tblForward, "SwitchIngress.act_forward", &tblForward_forward_action_id);
  bf_sys_assert(bf_status == BF_SUCCESS);

  // bf_status = bf_rt_action_name_to_id(
  //     tblForward, "SwitchIngress.nop", &tblForward_nop_action_id);
  // bf_sys_assert(bf_status == BF_SUCCESS);

  // Get field-ids for key field 
  bf_status = bf_rt_key_field_id_get(
      tblForward, "ig_intr_md.ingress_port", &tblForward_ingressPort);
  bf_sys_assert(bf_status == BF_SUCCESS);


  /***********************************************************************
   * DATA FIELD ID GET FOR "forward" ACTION
   **********************************************************************/
  bf_status = bf_rt_data_field_id_with_action_get(
      tblForward,
      "dport",
      tblForward_forward_action_id,
      &tblForward_forward_action_dstPort);
  bf_sys_assert(bf_status == BF_SUCCESS);



  // Allocate key and data once, and use reset across different uses
  bf_status = bf_rt_table_key_allocate(tblForward, &bfrtTableKey);
  bf_sys_assert(bf_status == BF_SUCCESS);

  bf_status = bf_rt_table_data_allocate(tblForward, &bfrtTableData);
  bf_sys_assert(bf_status == BF_SUCCESS);
}

// This function clears up any allocated memory during tableSetUp()
void tableTearDown() {
  bf_status_t bf_status;
  // Deallocate key and data
  bf_status = bf_rt_table_key_deallocate(bfrtTableKey);
  bf_sys_assert(bf_status == BF_SUCCESS);

  bf_status = bf_rt_table_data_deallocate(bfrtTableData);
  bf_sys_assert(bf_status == BF_SUCCESS);
}
// This function clears up any allocated mem during setUp()
void tearDown() {
  bf_status_t bf_status;
  bf_status = bf_rt_session_destroy(session);
  // Check for status
  bf_sys_assert(bf_status == BF_SUCCESS);
}


void perform_driver_func() {
  // Do initial set up
  setUp();
  // Do table level set up
  tableSetUp();

  bf_status_t bf_status = bf_rt_table_key_reset(tblForward, &bfrtTableKey);
  bf_sys_assert(bf_status == BF_SUCCESS);

  // Set value into the key object. Key type is "EXACT"
  bf_status = bf_rt_key_field_set_value(
      bfrtTableKey, tblForward_ingressPort, 12);
  bf_sys_assert(bf_status == BF_SUCCESS);

  // Data setup
  bf_status = bf_rt_table_action_data_reset(
      tblForward, tblForward_forward_action_id, &bfrtTableData);
  bf_sys_assert(bf_status == BF_SUCCESS);

  bf_status = bf_rt_data_field_set_value(
      bfrtTableData, tblForward_forward_action_dstPort, 20);
  bf_sys_assert(bf_status == BF_SUCCESS);

  // Add match-action into the table
  bf_status = bf_rt_table_entry_add(
        tblForward, session, &dev_tgt, 0, bfrtTableKey, bfrtTableData);
  bf_sys_assert(bf_status == BF_SUCCESS);

  bf_rt_session_complete_operations(session);

  printf("1 match action INSERTED. Press Enter to continue\n");
  char ch;
  ch = getchar();
  
  // Deletion
  bf_rt_table_key_reset(tblForward, &bfrtTableKey);

  // Set value into the key object. Key type is "EXACT"
  bf_status = bf_rt_key_field_set_value(
      bfrtTableKey, tblForward_ingressPort, 12);
  bf_sys_assert(bf_status == BF_SUCCESS);

  bf_rt_table_entry_del(tblForward, session, &dev_tgt, 0, bfrtTableKey);

  bf_rt_session_complete_operations(session);

  printf("1 match action DELETED. Press Enter to continue\n");
  ch = getchar();

  // Table tear down
  tableTearDown();
  // Tear Down
  tearDown();
  return;
}


int main(int argc, char **argv) {
  parse_opts_and_switchd_init(argc, argv);

  perform_driver_func();

  run_cli_or_cleanup();
  return 0;
}