
data:extend{
  {
    type = "string-setting",
    name = "ltn-temp-stop-mode",
    order = "aa",
    setting_type = "runtime-global",
    default_value = "remove-direction-smart",
    allowed_values = {"nochange","remove-all","remove-direction-all","remove-direction-smart"}
  },
  {
    type = "bool-setting",
    name = "ltn-opts-debug-print",
    order = "ad",
    setting_type = "runtime-global",
    default_value = true,
  },
}
