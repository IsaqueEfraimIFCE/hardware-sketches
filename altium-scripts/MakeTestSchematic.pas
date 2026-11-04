{..............................................................................}
{ MakeTestSchematic - creates a new schematic with a minimal test circuit:     }
{   VCC power port -> wire -> R1 (10k) -> wire -> GND power port               }
{ Run in Altium Designer: File >> Run Script >> browse to this file,           }
{ then run procedure MakeTestSchematic.                                        }
{..............................................................................}

Procedure MakeTestSchematic;
Var
    ServerDoc : IServerDocument;
    SchDoc    : ISch_Document;
    Component : ISch_Component;
    R         : ISch_Rectangle;
    Pin       : ISch_Pin;
    Wire      : ISch_Wire;
    PowerPort : ISch_PowerObject;
    TextLabel : ISch_Label;
Begin
    // Make sure the schematic editor server is loaded
    Client.StartServer('SCH');
    If SchServer = Nil Then
    Begin
        ShowMessage('Schematic server not available.');
        Exit;
    End;

    // Create a brand new free schematic document and bring it to front
    ServerDoc := Client.OpenNewDocument('SCH', 'TestSchematic.SchDoc', 'TestSchematic.SchDoc', False);
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
        // ------------------------------------------------------------------
        // R1 : simple two-pin resistor built from primitives
        // ------------------------------------------------------------------
        Component := SchServer.SchObjectFactory(eSchComponent, eCreate_GlobalCopy);
        Component.Location         := Point(MilsToCoord(3800), MilsToCoord(3000));
        Component.LibReference     := 'RES_TEST';
        Component.ComponentDescription := 'Test resistor';
        Component.CurrentPartID    := 1;
        Component.DisplayMode      := 0;

        Component.Designator.Text     := 'R1';
        Component.Designator.Location := Point(MilsToCoord(3950), MilsToCoord(3100));
        Component.Comment.Text        := '10k';
        Component.Comment.Location    := Point(MilsToCoord(3950), MilsToCoord(2850));

        // Body rectangle
        R := SchServer.SchObjectFactory(eRectangle, eCreate_GlobalCopy);
        R.Location  := Point(MilsToCoord(3950), MilsToCoord(2950));
        R.Corner    := Point(MilsToCoord(4250), MilsToCoord(3050));
        R.LineWidth := eSmall;
        R.IsSolid   := True;
        R.OwnerPartId          := 1;
        R.OwnerPartDisplayMode := 0;
        Component.AddSchObject(R);

        // Pin 1 (left, hotspot ends at x = 3800)
        Pin := SchServer.SchObjectFactory(ePin, eCreate_GlobalCopy);
        Pin.Designator  := '1';
        Pin.Name        := '1';
        Pin.Electrical  := eElectricPassive;
        Pin.Orientation := eRotate180;
        Pin.Location    := Point(MilsToCoord(3950), MilsToCoord(3000));
        Pin.PinLength   := MilsToCoord(150);
        Pin.ShowName       := False;
        Pin.ShowDesignator := False;
        Pin.OwnerPartId          := 1;
        Pin.OwnerPartDisplayMode := 0;
        Component.AddSchObject(Pin);

        // Pin 2 (right, hotspot ends at x = 4400)
        Pin := SchServer.SchObjectFactory(ePin, eCreate_GlobalCopy);
        Pin.Designator  := '2';
        Pin.Name        := '2';
        Pin.Electrical  := eElectricPassive;
        Pin.Orientation := eRotate0;
        Pin.Location    := Point(MilsToCoord(4250), MilsToCoord(3000));
        Pin.PinLength   := MilsToCoord(150);
        Pin.ShowName       := False;
        Pin.ShowDesignator := False;
        Pin.OwnerPartId          := 1;
        Pin.OwnerPartDisplayMode := 0;
        Component.AddSchObject(Pin);

        SchDoc.RegisterSchObjectInContainer(Component);
        SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
            SCHM_PrimitiveRegistration, Component.I_ObjectAddress);

        // ------------------------------------------------------------------
        // Wire: VCC riser -> pin 1 of R1
        // ------------------------------------------------------------------
        Wire := SchServer.SchObjectFactory(eWire, eCreate_GlobalCopy);
        Wire.Location     := Point(MilsToCoord(3600), MilsToCoord(3200));
        Wire.InsertVertex := 1;
        Wire.SetState_Vertex(1, Point(MilsToCoord(3600), MilsToCoord(3200)));
        Wire.InsertVertex := 2;
        Wire.SetState_Vertex(2, Point(MilsToCoord(3600), MilsToCoord(3000)));
        Wire.InsertVertex := 3;
        Wire.SetState_Vertex(3, Point(MilsToCoord(3800), MilsToCoord(3000)));
        SchDoc.RegisterSchObjectInContainer(Wire);
        SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
            SCHM_PrimitiveRegistration, Wire.I_ObjectAddress);

        // ------------------------------------------------------------------
        // Wire: pin 2 of R1 -> down to GND
        // ------------------------------------------------------------------
        Wire := SchServer.SchObjectFactory(eWire, eCreate_GlobalCopy);
        Wire.Location     := Point(MilsToCoord(4400), MilsToCoord(3000));
        Wire.InsertVertex := 1;
        Wire.SetState_Vertex(1, Point(MilsToCoord(4400), MilsToCoord(3000)));
        Wire.InsertVertex := 2;
        Wire.SetState_Vertex(2, Point(MilsToCoord(4600), MilsToCoord(3000)));
        Wire.InsertVertex := 3;
        Wire.SetState_Vertex(3, Point(MilsToCoord(4600), MilsToCoord(2800)));
        SchDoc.RegisterSchObjectInContainer(Wire);
        SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
            SCHM_PrimitiveRegistration, Wire.I_ObjectAddress);

        // ------------------------------------------------------------------
        // VCC power port (bar style, pointing up)
        // ------------------------------------------------------------------
        PowerPort := SchServer.SchObjectFactory(ePowerObject, eCreate_GlobalCopy);
        PowerPort.Location    := Point(MilsToCoord(3600), MilsToCoord(3200));
        PowerPort.Orientation := eRotate90;
        PowerPort.Style       := ePowerBar;
        PowerPort.Text        := 'VCC';
        PowerPort.ShowNetName := True;
        SchDoc.RegisterSchObjectInContainer(PowerPort);
        SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
            SCHM_PrimitiveRegistration, PowerPort.I_ObjectAddress);

        // ------------------------------------------------------------------
        // GND power port (signal-ground style, pointing down)
        // ------------------------------------------------------------------
        PowerPort := SchServer.SchObjectFactory(ePowerObject, eCreate_GlobalCopy);
        PowerPort.Location    := Point(MilsToCoord(4600), MilsToCoord(2800));
        PowerPort.Orientation := eRotate270;
        PowerPort.Style       := ePowerGndSignal;
        PowerPort.Text        := 'GND';
        PowerPort.ShowNetName := True;
        SchDoc.RegisterSchObjectInContainer(PowerPort);
        SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
            SCHM_PrimitiveRegistration, PowerPort.I_ObjectAddress);

        // ------------------------------------------------------------------
        // Title text
        // ------------------------------------------------------------------
        TextLabel := SchServer.SchObjectFactory(eLabel, eCreate_GlobalCopy);
        TextLabel.Location := Point(MilsToCoord(3600), MilsToCoord(3500));
        TextLabel.Text     := 'Minimal test schematic';
        SchDoc.RegisterSchObjectInContainer(TextLabel);
        SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
            SCHM_PrimitiveRegistration, TextLabel.I_ObjectAddress);

    Finally
        SchServer.ProcessControl.PostProcess(SchDoc, '');
    End;

    // Refresh the view
    SchDoc.GraphicallyInvalidate;
    Client.SendMessage('SCH:ZoomAllObjects', '', 255, Client.CurrentView);
End;
