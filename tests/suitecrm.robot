*** Settings ***
Library    SSHLibrary
Library    String

*** Variables ***
${HOST}    suitecrm.example.org
${ADMIN_USER}    admin
${ADMIN_PASSWORD}    Nethesis,1234
${module_id}    ${EMPTY}

*** Keywords ***
Login to cluster-admin
    New Page    https://${NODE_ADDR}/cluster-admin/
    Fill Text    text="Username"    ${ADMIN_USER}
    Click    button >> text="Continue"
    Fill Text    text="Password"    ${ADMIN_PASSWORD}
    Click    button >> text="Log in"
    Wait For Elements State    css=#main-content    visible    timeout=10s

SuiteCRM answers through Traefik
    # SuiteCRM serves its application page with 200 once installed; the
    # installer would answer with a redirect. 000: no answer, 404: Traefik
    # has no route, 502: Apache is not listening yet.
    ${status} =    Execute Command    curl -k -s -o /dev/null --max-time 10 -w '\%{http_code}' --resolve ${HOST}:443:127.0.0.1 https://${HOST}/
    ${status} =    Strip String    ${status}
    Should Be Equal    ${status}    200    https://${HOST}/ answered HTTP ${status}
    ${page} =    Execute Command    curl -k -s --max-time 10 --resolve ${HOST}:443:127.0.0.1 https://${HOST}/
    Should Contain    ${page}    <title>SuiteCRM</title>

*** Test Cases ***
Check if suitecrm is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0    add-module failed: ${output}
    &{output} =    Evaluate    ${output}
    Set Global Variable    ${module_id}    ${output.module_id}

Take screenshots
    [Tags]    ui
    Import Library    Browser
    New Browser    chromium    headless=True
    New Context    ignoreHTTPSErrors=True
    Login to cluster-admin
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}
    Wait For Elements State    iframe >>> h2 >> text="Status"    visible    timeout=10s
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/1._Status.png
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}?page=settings
    Wait For Elements State    iframe >>> h2 >> text="Settings"    visible    timeout=10s
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/2._Settings.png
    Close Browser

Check if suitecrm can be configured
    # Valid against configure-module/validate-input.json
    ${output}  ${rc} =    Execute Command    api-cli run module/${module_id}/configure-module --data '{"host":"${HOST}","http2https":true,"lets_encrypt":false}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0    configure-module failed: ${output}

Check if suitecrm configuration reads back
    ${output}    ${rc} =    Execute Command    api-cli run module/${module_id}/get-configuration
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0    get-configuration failed: ${output}
    &{config} =    Evaluate    json.loads(r'''${output}''')    modules=json
    Should Be Equal    ${config.host}    ${HOST}

Check if suitecrm works as expected
    Wait Until Keyword Succeeds    15 min    10 sec    SuiteCRM answers through Traefik

Check if suitecrm is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
