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
  var TemplateUtils = require('utils/template-utils');

  /*
    Inputs must define wizard_field="KEY"
    Inputs with the wizard_field attr will not be considered
   */

  return {
    'retrieve': _retrieveWizardFields,
    'fill': _fillWizardFields
  }

  function _retrieveWizardFields(context) {
    var templateJSON = {};
    var fields = $('[wizard_field]', context);

    fields.each(function() {
      var field = $(this);

      if (field.prop('wizard_field_disabled') != true &&
            field.val() != null && field.val().length &&
            (field.attr("type") != "checkbox" || field.prop("checked")) &&
            (field.attr("type") != "radio" || field.prop("checked"))) {
        var field_name = field.attr('wizard_field');

        if (field.attr('wizard_field_64') == "true"){
          templateJSON[field_name] = btoa(field.val());
        } else {
          templateJSON[field_name] = field.val();
        }
      }
    });

    return templateJSON;
  }

  // TODO: wizard_field_64 for fill method
  function _fillWizardFields(context, templateJSON) {
    var fields = $('[wizard_field]', context);

    fields.each(function() {
      var field = $(this);
      var field_name = field.attr('wizard_field');
      var field_val = templateJSON[field_name];

      if (field_val) {
        if (field.is("select")){
          var option = $("option", field).filter(function() {
            return $(this).attr('value').toUpperCase() == field_val.toUpperCase();
          });

          field.val(option.val()).change();
        } else {  // if (field.is("input")){
          switch (field.attr("type")){
          case "radio":
            var checked = (field.val().toUpperCase() == field_val.toUpperCase());

            field.prop("checked", checked);

            if (checked) {
              field.change();
            }
            break;
          case "checkbox":
            var checked = (field.val().toUpperCase() == field_val.toUpperCase());

            field.prop("checked", checked);

            if (checked) {
              field.change();
            }
            break;
          default:
            field.val(
              TemplateUtils.escapeDoubleQuotes(
                TemplateUtils.htmlDecode(field_val)));
            field.change();
          }
        }

        delete templateJSON[field_name];
      }
    });
  }
});
