import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "NamedScratchpadDefinitions.js" as Definitions

Item {
    id: root
    width: parent ? parent.width : 0
    height: 560

    property string mode: "list"
    property var definitions: []
    property var editingDefinition: null
    property string errorText: ""
    property string deleteId: ""
    property string deleteName: ""

    focus: visible

    signal closeRequested()
    signal storeChanged(var store)

    function currentStore() {
        const settings = SettingsData.getPluginSettingsForPlugin("scratchpadHelper");
        return settings.namedManagerStore === undefined ? null : settings.namedManagerStore;
    }

    function refresh() {
        const loaded = Definitions.loadStore(currentStore());
        if (!loaded.valid) {
            definitions = [];
            errorText = loaded.error;
            return;
        }
        definitions = loaded.store.definitions.map(Definitions.canonicalDefinition).sort(Definitions.compareDefinitions);
        const validation = Definitions.validateDefinitions(loaded.store.definitions);
        if (!validation.valid)
            errorText = "Some stored named scratchpads need attention.";
        if (errorText === "Stored named scratchpads could not be read.")
            errorText = "";
    }

    function persist(result) {
        if (!result.valid) {
            errorText = friendlyError(result.errors.length ? result.errors[0] : null);
            return false;
        }
        SettingsData.setPluginSetting("scratchpadHelper", "namedManagerStore", result.store);
        storeChanged(result.store);
        errorText = "";
        refresh();
        return true;
    }

    function friendlyError(error) {
        if (!error) return "Couldn't save this named scratchpad.";
        if (error.code === "overlap" || error.code === "duplicate") return "This definition conflicts with another named scratchpad.";
        if (error.field === "displayName" && error.code === "required") return "Enter a name.";
        if (error.field === "identity" && error.code === "required") return "Enter an application ID or window title.";
        if (error.field === "launchCommand" && error.code === "required") return "Enter a launch command.";
        if (error.field === "appId") return "Application ID contains unsupported characters.";
        if (error.field === "title") return "Window title contains unsupported characters.";
        return String(error.message || "Couldn't save this named scratchpad.");
    }

    function openAdd() {
        editingDefinition = null;
        nameField.text = "";
        appField.text = "";
        titleField.text = "";
        commandField.text = "";
        enabledToggle.checked = true;
        errorText = "";
        mode = "editor";
        nameField.forceActiveFocus();
    }

    function openEdit(definition) {
        editingDefinition = definition;
        nameField.text = definition.displayName;
        appField.text = definition.appId;
        titleField.text = definition.title;
        commandField.text = definition.launchCommand;
        enabledToggle.checked = definition.enabled;
        errorText = "";
        mode = "editor";
        nameField.forceActiveFocus();
    }

    function saveEditor() {
        const fields = {"displayName": nameField.text, "appId": appField.text,
            "title": titleField.text, "launchCommand": commandField.text,
            "enabled": enabledToggle.checked};
        const result = editingDefinition
            ? Definitions.updateDefinition(currentStore(), editingDefinition.id, fields)
            : Definitions.createDefinition(currentStore(), fields);
        if (persist(result)) {
            returnToList();
        }
    }

    function identitySummary(definition) {
        if (definition.appId && definition.title) return definition.appId + "  •  Title: " + definition.title;
        if (definition.appId) return definition.appId;
        return "Title: " + definition.title;
    }

    function navigateBack() {
        if (mode === "editor" || mode === "delete") {
            returnToList();
            return;
        }
        closeRequested();
    }

    function returnToList() {
        editingDefinition = null;
        deleteId = "";
        deleteName = "";
        errorText = "";
        mode = "list";
        Qt.callLater(() => root.forceActiveFocus());
    }

    Component.onCompleted: refresh()
    onVisibleChanged: {
        if (visible && mode === "list")
            Qt.callLater(() => root.forceActiveFocus());
    }
    onModeChanged: {
        if (mode === "delete" || mode === "list")
            Qt.callLater(() => root.forceActiveFocus());
    }

    Keys.onEscapePressed: event => {
        navigateBack();
        event.accepted = true;
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spacingM

        Row {
            width: parent.width
            spacing: Theme.spacingS

            DankActionButton {
                iconName: "arrow_back"
                buttonSize: Theme.iconSize + Theme.spacingM
                tooltipText: "Back"
                tooltipSide: "bottom"
                onClicked: root.navigateBack()
            }
            Column {
                width: parent.width - Theme.iconSize - Theme.spacingM * 2 - addButton.width
                anchors.verticalCenter: parent.verticalCenter
                StyledText {
                    text: root.mode === "editor" ? (root.editingDefinition ? "Edit named scratchpad" : "Add named scratchpad") : "Named scratchpads"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                }
                StyledText {
                    visible: root.mode === "list"
                    text: root.definitions.length + (root.definitions.length === 1 ? " definition" : " definitions")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
            DankButton {
                id: addButton
                text: "Add"
                iconName: "add"
                visible: root.mode === "list" && root.definitions.length > 0
                onClicked: root.openAdd()
            }
        }

        StyledRect {
            width: parent.width
            height: errorLabel.implicitHeight + Theme.spacingS * 2
            visible: root.errorText.length > 0
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.error, 0.12)
            StyledText {
                id: errorLabel
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                text: root.errorText
                color: Theme.error
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }

        Item {
            width: parent.width
            height: parent.height - y
            visible: root.mode === "list"

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingM
                visible: root.definitions.length === 0 && root.errorText.length === 0
                StyledText { text: "No named scratchpads yet."; color: Theme.surfaceVariantText }
                DankButton { anchors.horizontalCenter: parent.horizontalCenter; text: "Add named scratchpad"; onClicked: root.openAdd() }
            }

            ListView {
                anchors.fill: parent
                visible: root.definitions.length > 0
                clip: true
                spacing: Theme.spacingS
                model: root.definitions
                boundsBehavior: Flickable.StopAtBounds

                delegate: StyledRect {
                    property var definition: modelData
                    width: ListView.view.width
                    height: 72
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS
                        Column {
                            width: parent.width - enabledSwitch.width - editButton.width - deleteButton.width - parent.spacing * 3
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXXS
                            StyledText { width: parent.width; text: definition.displayName; color: Theme.surfaceText; font.weight: Font.Medium; elide: Text.ElideRight }
                            StyledText { width: parent.width; text: root.identitySummary(definition); color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideRight }
                        }
                        DankToggle {
                            id: enabledSwitch
                            anchors.verticalCenter: parent.verticalCenter
                            checked: definition.enabled
                            onToggled: isChecked => root.persist(Definitions.setDefinitionEnabled(root.currentStore(), definition.id, isChecked))
                        }
                        DankActionButton { id: editButton; iconName: "edit"; buttonSize: Theme.iconSize + Theme.spacingM; tooltipText: "Edit"; tooltipSide: "top"; onClicked: root.openEdit(definition) }
                        DankActionButton {
                            id: deleteButton
                            iconName: "delete"
                            iconColor: Theme.error
                            buttonSize: Theme.iconSize + Theme.spacingM
                            tooltipText: "Delete"
                            tooltipSide: "top"
                            onClicked: { root.deleteId = definition.id; root.deleteName = definition.displayName; root.mode = "delete"; }
                        }
                    }
                }
            }
        }

        StyledRect {
            width: parent.width
            height: editorColumn.implicitHeight + Theme.spacingM * 2
            visible: root.mode === "editor"
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh
            Column {
                id: editorColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM
                component Field : Column {
                    required property string label
                    property string help: ""
                    property alias text: input.text
                    width: parent.width
                    spacing: Theme.spacingXS
                    StyledText { text: parent.label; color: Theme.surfaceText; font.weight: Font.Medium }
                    StyledText { width: parent.width; text: parent.help; visible: text.length > 0; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; wrapMode: Text.WordWrap }
                    DankTextField { id: input; width: parent.width }
                }
                Field { id: nameField; label: "Display name"; help: "Name shown in Scratchpad Helper." }
                Field { id: appField; label: "Application ID"; help: "Exact app ID used by the window." }
                Field { id: titleField; label: "Window title"; help: "Optional exact window title." }
                Field { id: commandField; label: "Launch command"; help: "Command Mango can use when the scratchpad is not open." }
                Item {
                    width: parent.width
                    height: Math.max(enabledLabel.implicitHeight, enabledToggle.implicitHeight)
                    StyledText {
                        id: enabledLabel
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Enabled"
                        color: Theme.surfaceText
                    }
                    DankToggle {
                        id: enabledToggle
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        checked: true
                    }
                }
                Flow {
                    width: parent.width
                    spacing: Theme.spacingS
                    layoutDirection: Qt.RightToLeft
                    DankButton { text: "Save"; backgroundColor: Theme.primary; textColor: Theme.primaryText; onClicked: root.saveEditor() }
                    DankButton { text: "Cancel"; onClicked: root.returnToList() }
                }
            }
        }

        StyledRect {
            width: parent.width
            height: deleteColumn.implicitHeight + Theme.spacingM * 2
            visible: root.mode === "delete"
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh
            Column {
                id: deleteColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM
                StyledText { text: "Delete “" + root.deleteName + "”?"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium }
                StyledText { width: parent.width; text: "This removes the definition from Scratchpad Helper. It won't close the window."; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap }
                Flow {
                    width: parent.width
                    spacing: Theme.spacingS
                    layoutDirection: Qt.RightToLeft
                    DankButton { text: "Delete"; backgroundColor: Theme.error; textColor: Theme.primaryText; onClicked: { if (root.persist(Definitions.deleteDefinition(root.currentStore(), root.deleteId))) root.returnToList(); } }
                    DankButton { text: "Cancel"; onClicked: root.returnToList() }
                }
            }
        }
    }
}
