/* -------------------------------------------------------------------------- */
/* Copyright 2002-2015, OpenNebula Project, OpenNebula Systems                */
/*                                                                            */
/* Licensed under the Apache License, Version 2.0 (the "License"); you may    */
/* not use this file except in compliance with the License. You may obtain    */
/* a copy of the License at                                                   */
/*                                                                            */
/* http://www.apache.org/licenses/LICENSE-2.0                                 */
/*                                                                            */
/* Unless required by applicable law or agreed to in writing, software        */
/* distributed under the License is distributed on an "AS IS" BASIS,          */
/* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   */
/* See the License for the specific language governing permissions and        */
/* limitations under the License.                                             */
/* -------------------------------------------------------------------------- */

define(function(require) {
  /*
    DEPENDENCIES
   */

  var BaseFormPanel = require('utils/form-panels/form-panel');
  var Sunstone = require('sunstone');
  var Locale = require('utils/locale');
  var Tips = require('utils/tips');
  var Notifier = require('utils/notifier');
  var ResourceSelect = require('utils/resource-select');
  var VCenterClusters = require('utils/vcenter/clusters');
  var Config = require('sunstone-config');

  /*
    TEMPLATES
   */

  var TemplateWizardHTML = require('hbs!./create/wizard');

  /*
    CONSTANTS
   */

  var FORM_PANEL_ID = require('./create/formPanelId');
  var TAB_ID = require('../tabId');

  /*
    CONSTRUCTOR
   */

  function FormPanel() {
    this.formPanelId = FORM_PANEL_ID;
    this.tabId = TAB_ID;
    this.actions = {
      'create': {
        'title': Locale.tr("Create Host"),
        'buttonText': Locale.tr("Create"),
        'resetButton': true
      }
    }

    this.vCenterClusters = new VCenterClusters();

    var that = this;

    that.vmMadNameList = [];
    if (Config.onedConf.VM_MAD !== undefined) {
      $.each(Config.onedConf.VM_MAD, function(index, vmMad) {
        that.vmMadNameList.push(vmMad["NAME"]);
      });
    }

    that.imMadNameList = [];
    if (Config.onedConf.IM_MAD !== undefined) {
      $.each(Config.onedConf.IM_MAD, function(index, imMad) {
        that.imMadNameList.push(imMad["NAME"]);
      });
    }

    BaseFormPanel.call(this);
  };

  FormPanel.FORM_PANEL_ID = FORM_PANEL_ID;
  FormPanel.prototype = Object.create(BaseFormPanel.prototype);
  FormPanel.prototype.constructor = FormPanel;
  FormPanel.prototype.htmlWizard = _htmlWizard;
  FormPanel.prototype.submitWizard = _submitWizard;
  FormPanel.prototype.onShow = _onShow;
  FormPanel.prototype.setup = _setup;

  return FormPanel;

  /*
    FUNCTION DEFINITIONS
   */

  function _htmlWizard() {
    return TemplateWizardHTML({
      'formPanelId': this.formPanelId,
      'vCenterClustersHTML': this.vCenterClusters.html(),
      'vmMadNameList': this.vmMadNameList,
      'imMadNameList': this.imMadNameList
    });
  }

  function _setup(context) {
    var that = this;

    $(".drivers", context).hide();

    $("#host_type_mad", context).on("change", function() {
      $("#vmm_mad", context).val(this.value).change();
      $("#im_mad", context).val(this.value).change();

      if (this.value == "custom") {
        $(".vcenter_credentials", context).hide();
        $("#name_container", context).show();
        Sunstone.showFormPanelSubmit(TAB_ID);
        $(".drivers", context).show();
      } else if (this.value == "vcenter") {
        $("#name_container", context).hide();
        $(".vcenter_credentials", context).show();
        Sunstone.hideFormPanelSubmit(TAB_ID);
        $(".drivers", context).hide();
      } else {
        $(".vcenter_credentials", context).hide();
        $("#name_container", context).show();
        Sunstone.showFormPanelSubmit(TAB_ID);
        $(".drivers", context).hide();
      }
    });

    $("#host_type_mad", context).change();

    $("#get_vcenter_clusters", context).on("click", function() {
      // TODO notify if credentials empty

      var vcenter_user = $("#vcenter_user", context).val();
      var vcenter_password = $("#vcenter_password", context).val();
      var vcenter_host = $("#vcenter_host", context).val();

      that.vCenterClusters.insert({
        container: context,
        vcenter_user: vcenter_user,
        vcenter_password: vcenter_password,
        vcenter_host: vcenter_host,
        success: function(){
          $("#vcenter_user", context).attr("disabled", "disabled");
          $("#vcenter_password", context).attr("disabled", "disabled");
          $("#vcenter_host", context).attr("disabled", "disabled");
          $("#get_vcenter_clusters", context).hide();
          $(".import_vcenter_clusters_div", context).show();
        }
      });

      return false;
    });

    $("#import_vcenter_clusters", context).on("click", function() {
      $(this).hide();

      var cluster_id = $('#host_cluster_id .resource_list_select', context).val();
      if (!cluster_id) cluster_id = "-1";

      that.vCenterClusters.import(context, cluster_id);

      return false;
    });

    // Show custom driver input only when custom is selected in selects
    $('input[name="custom_vmm_mad"],' + 'input[name="custom_im_mad"]',
        context).parent().hide();

    $('select#vmm_mad', context).change(function() {
      if ($(this).val() == "custom")
          $('input[name="custom_vmm_mad"]').parent().show();
      else
          $('input[name="custom_vmm_mad"]').parent().hide();
    });

    $('select#im_mad', context).change(function() {
      if ($(this).val() == "custom")
          $('input[name="custom_im_mad"]').parent().show();
      else
          $('input[name="custom_im_mad"]').parent().hide();
    });

    $('#create_host_form').on("keyup keypress", function(e) {
          var code = e.keyCode || e.which;
          if (code  == 13) {
            e.preventDefault();
            return false;
          }
        });

    Tips.setup();
    return false;
  }

  function _submitWizard(context) {
    var name = $('#name', context).val();
    if (!name) {
      Sunstone.hideFormPanelLoading(this.tabId);
      Notifier.notifyError(Locale.tr("Host name missing!"));
      return false;
    }

    var cluster_id = $('#host_cluster_id .resource_list_select', context).val();
    if (!cluster_id) cluster_id = "-1";

    var vmm_mad = $('select#vmm_mad', context).val();
    vmm_mad = vmm_mad == "custom" ? $('input[name="custom_vmm_mad"]').val() : vmm_mad;
    var im_mad = $('select#im_mad', context).val();
    im_mad = im_mad == "custom" ? $('input[name="custom_im_mad"]').val() : im_mad;

    var host_json = {
      "host": {
        "name": name,
        "vm_mad": vmm_mad,
        "im_mad": im_mad,
        "cluster_id": cluster_id
      }
    };

    //Create the OpenNebula.Host.
    //If it is successfull we refresh the list.
    Sunstone.runAction("Host.create", host_json);
    return false;
  }

  function _onShow(context) {
    $("#name", context).focus();

    var cluster_id = $("#host_cluster_id .resource_list_select", context).val();
    if (!cluster_id) cluster_id = "0";

    ResourceSelect.insert({
        context: $('#host_cluster_id', context),
        resourceName: 'Cluster',
        initValue: cluster_id
      });

    $("#host_type_mad", context).change();

    return false;
  }
});
