{..............................................................................}
{ MakeTestSchematic2 - creates a new schematic with a minimal voltage divider: }
{   VCC -> R1 (10k) -> OUT net label -> R2 (10k) -> GND                        }
{ Run in Altium Designer: File >> Run Script, pick MakeTestSchematic2.         }
{..............................................................................}

Function MakeResistor(SchDoc : ISch_Document; RefDes : String; Value : String;
                      X : Integer; YTop : Integer) : ISch_Component;
Var
    Component : ISch_Component;
    R         : ISch_Rectangle;
    Pin       : ISch_Pin;
Begin
    // Vertical two-pin resistor. Pin 1 hotspot at (X, YTop),
    // pin 2 hotspot at (X, YTop - 600). Body from YTop-150 to YTop-450.
    Component := SchServer.SchObjectFactory(eSchComponent, eCreate_GlobalCopy);
    Component.Location             := Point(MilsToCoord(X), MilsToCoord(YTop));
    Component.LibReference         := 'RES_TEST';
    Component.ComponentDescription := 'Test resistor';
    Component.CurrentPartID        := 1;
    Component.DisplayMode          := 0;

    Component.Designator.Text     := RefDes;
    Component.Designator.Location := Point(MilsToCoord(X + 100), MilsToCoord(YTop - 250));
    Component.Comment.Text        := Value;
    Component.Comment.Location    := Point(MilsToCoord(X + 100), MilsToCoord(YTop - 400));

    // Body rectangle
    R := SchServer.SchObjectFactory(eRectangle, eCreate_GlobalCopy);
    R.Location  := Point(MilsToCoord(X - 50), MilsToCoord(YTop - 450));
    R.Corner    := Point(MilsToCoord(X + 50), MilsToCoord(YTop - 150));
    R.LineWidth := eSmall;
    R.IsSolid   := True;
    R.OwnerPartId          := 1;
    R.OwnerPartDisplayMode := 0;
    Component.AddSchObject(R);

    // Pin 1 (top, points up, hotspot at YTop)
    Pin := SchServer.SchObjectFactory(ePin, eCreate_GlobalCopy);
    Pin.Designator  := '1';
    Pin.Name        := '1';
    Pin.Electrical  := eElectricPassive;
    Pin.Orientation := eRotate90;
    Pin.Location    := Point(MilsToCoord(X), MilsToCoord(YTop - 150));
    Pin.PinLength   := MilsToCoord(150);
    Pin.ShowName       := False;
    Pin.ShowDesignator := False;
    Pin.OwnerPartId          := 1;
    Pin.OwnerPartDisplayMode := 0;
    Component.AddSchObject(Pin);

    // Pin 2 (bottom, points down, hotspot at YTop - 600)
    Pin := SchServer.SchObjectFactory(ePin, eCreate_GlobalCopy);
    Pin.Designator  := '2';
    Pin.Name        := '2';
    Pin.Electrical  := eElectricPassive;
    Pin.Orientation := eRotate270;
    Pin.Location    := Point(MilsToCoord(X), MilsToCoord(YTop - 450));
    Pin.PinLength   := MilsToCoord(150);
    Pin.ShowName       := False;
    Pin.ShowDesignator := False;
    Pin.OwnerPartId          := 1;
    Pin.OwnerPartDisplayMode := 0;
    Component.AddSchObject(Pin);

    SchDoc.RegisterSchObjectInContainer(Component);
    SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
        SCHM_PrimitiveRegistration, Component.I_ObjectAddress);

    Result := Component;
End;

Procedure MakeVerticalWire(SchDoc : ISch_Document; X : Integer; Y1 : Integer; Y2 : Integer);
Var
    Wire : ISch_Wire;
Begin
    Wire := SchServer.SchObjectFactory(eWire, eCreate_GlobalCopy);
    Wire.Location     := Point(MilsToCoord(X), MilsToCoord(Y1));
    Wire.InsertVertex := 1;
    Wire.SetState_Vertex(1, Point(MilsToCoord(X), MilsToCoord(Y1)));
    Wire.InsertVertex := 2;
    Wire.SetState_Vertex(2, Point(MilsToCoord(X), MilsToCoord(Y2)));
    SchDoc.RegisterSchObjectInContainer(Wire);
    SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
        SCHM_PrimitiveRegistration, Wire.I_ObjectAddress);
End;

Procedure MakeTestSchematic2;
Var
    ServerDoc : IServerDocument;
    SchDoc    : ISch_Document;
    PowerPort : ISch_PowerObject;
    NetLabel  : ISch_NetLabel;
    TextLabel : ISch_Label;
Begin
    Client.StartServer('SCH');
    If SchServer = Nil Then
    Begin
        ShowMessage('Schematic server not available.');
        Exit;
    End;

    ServerDoc := Client.OpenNewDocument('SCH', 'TestSchematic2.SchDoc', 'TestSchematic2.SchDoc', False);
    If ServerDoc = Nil Then
    Begin
        ShowMessage('Could not create a new schematic document.');
        Exit;
    End;
    Client.ShowDocument(ServerDoc);

    SchDoc := SchServer.GetCurrentSchDocument;
    If SchDoc = Nil Then
        SchDoc := SchServer.GetSchDocumentByPath(ServerDoc.FileName);
    If SchDoc = Nil Then
    Begin
        ShowMessage('Schematic document was created but could not be accessed.');
        Exit;
    End;

    SchServer.ProcessControl.PreProcess(SchDoc, '');
    Try
        // Column at X = 4000, from VCC (Y=4000) down to GND (Y=1800)
        // VCC port -> wire -> R1 -> wire (OUT) -> R2 -> wire -> GND port

        MakeResistor(SchDoc, 'R1', '10k', 4000, 3800);  // pins at 3800 / 3200
        MakeResistor(SchDoc, 'R2', '10k', 4000, 2800);  // pins at 2800 / 2200

        MakeVerticalWire(SchDoc, 4000, 4000, 3800);     // VCC -> R1.1
        MakeVerticalWire(SchDoc, 4000, 3200, 2800);     // R1.2 -> R2.1 (OUT)
        MakeVerticalWire(SchDoc, 4000, 2200, 2000);     // R2.2 -> GND

        // VCC power port
        PowerPort := SchServer.SchObjectFactory(ePowerObject, eCreate_GlobalCopy);
        PowerPort.Location    := Point(MilsToCoord(4000), MilsToCoord(4000));
        PowerPort.Orientation := eRotate90;
        PowerPort.Style       := ePowerBar;
        PowerPort.Text        := 'VCC';
        PowerPort.ShowNetName := True;
        SchDoc.RegisterSchObjectInContainer(PowerPort);
        SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
            SCHM_PrimitiveRegistration, PowerPort.I_ObjectAddress);

        // GND power port
        PowerPort := SchServer.SchObjectFactory(ePowerObject, eCreate_GlobalCopy);
        PowerPort.Location    := Point(MilsToCoord(4000), MilsToCoord(2000));
        PowerPort.Orientation := eRotate270;
        PowerPort.Style       := ePowerGndSignal;
        PowerPort.Text        := 'GND';
        PowerPort.ShowNetName := True;
        SchDoc.RegisterSchObjectInContainer(PowerPort);
        SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
            SCHM_PrimitiveRegistration, PowerPort.I_ObjectAddress);

        // Net label OUT on the middle wire
        NetLabel := SchServer.SchObjectFactory(eNetLabel, eCreate_GlobalCopy);
        NetLabel.Location    := Point(MilsToCoord(4000), MilsToCoord(3000));
        NetLabel.Text        := 'OUT';
        NetLabel.Orientation := eRotate0;
        SchDoc.RegisterSchObjectInContainer(NetLabel);
        SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
            SCHM_PrimitiveRegistration, NetLabel.I_ObjectAddress);

        // Title text
        TextLabel := SchServer.SchObjectFactory(eLabel, eCreate_GlobalCopy);
        TextLabel.Location := Point(MilsToCoord(3600), MilsToCoord(4300));
        TextLabel.Text     := 'Test schematic 2 - voltage divider';
        SchDoc.RegisterSchObjectInContainer(TextLabel);
        SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
            SCHM_PrimitiveRegistration, TextLabel.I_ObjectAddress);

    Finally
        SchServer.ProcessControl.PostProcess(SchDoc, '');
    End;

    SchDoc.GraphicallyInvalidate;
    Client.SendMessage('SCH:ZoomAllObjects', '', 255, Client.CurrentView);
End;
