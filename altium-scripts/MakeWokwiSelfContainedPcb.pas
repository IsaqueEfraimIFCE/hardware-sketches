{..............................................................................}
{ MakeWokwiSelfContainedPcb                                                   }
{                                                                              }
{ Creates two documents without using any external libraries:                   }
{   1) WokwiSelfContained.SchDoc - readable schematic with net labels.          }
{   2) WokwiSelfContained.PcbDoc - starter PCB drawn directly from pads,        }
{      tracks and text. No footprint lookup, no ECO, no installed libraries.    }
{                                                                              }
{ The PCB is a carrier-board style layout: module headers for Wokwi modules,    }
{ a 2x15 ESP32-C6 header, PTH resistors, a PTH pushbutton, silkscreen labels,   }
{ and simple top-layer routed traces.                                           }
{..............................................................................}

Procedure SchReg(SchDoc : ISch_Document; Obj : ISch_GraphicalObject);
Begin
    SchDoc.RegisterSchObjectInContainer(Obj);
    SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
        SCHM_PrimitiveRegistration, Obj.I_ObjectAddress);
End;

Procedure PcbReg(Board : IPCB_Board; Obj : IPCB_Primitive);
Begin
    Board.AddPCBObject(Obj);
    PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast,
        PCBM_BoardRegisteration, Obj.I_ObjectAddress);
End;

Procedure WireSeg(SchDoc : ISch_Document; X1, Y1, X2, Y2 : Integer);
Var
    Wire : ISch_Wire;
Begin
    Wire := SchServer.SchObjectFactory(eWire, eCreate_GlobalCopy);
    Wire.Location     := Point(MilsToCoord(X1), MilsToCoord(Y1));
    Wire.InsertVertex := 1;
    Wire.SetState_Vertex(1, Point(MilsToCoord(X1), MilsToCoord(Y1)));
    Wire.InsertVertex := 2;
    Wire.SetState_Vertex(2, Point(MilsToCoord(X2), MilsToCoord(Y2)));
    SchReg(SchDoc, Wire);
End;

Procedure NetAt(SchDoc : ISch_Document; X, Y : Integer; Net : String);
Var
    NetLabel : ISch_NetLabel;
Begin
    NetLabel := SchServer.SchObjectFactory(eNetLabel, eCreate_GlobalCopy);
    NetLabel.Location    := Point(MilsToCoord(X), MilsToCoord(Y));
    NetLabel.Text        := Net;
    NetLabel.Orientation := eRotate0;
    SchReg(SchDoc, NetLabel);
End;

Procedure StubH(SchDoc : ISch_Document; XPin, Y, Dir : Integer; Net : String);
Begin
    WireSeg(SchDoc, XPin, Y, XPin + Dir * 300, Y);
    If Dir < 0 Then
        NetAt(SchDoc, XPin - 300, Y, Net)
    Else
        NetAt(SchDoc, XPin + 50, Y, Net);
End;

Procedure StubV(SchDoc : ISch_Document; X, YPin, Dir : Integer; Net : String);
Begin
    WireSeg(SchDoc, X, YPin, X, YPin + Dir * 200);
    NetAt(SchDoc, X, YPin + Dir * 200, Net);
End;

Function AddSchBlock(SchDoc : ISch_Document; RefDes : String; Comment : String;
                     X : Integer; Y : Integer; Width : Integer;
                     LeftPins : TStringList; RightPins : TStringList) : ISch_Component;
Var
    Component : ISch_Component;
    R         : ISch_Rectangle;
    Pin       : ISch_Pin;
    i, H, N   : Integer;
    PinNo     : Integer;
Begin
    N := LeftPins.Count;
    If RightPins.Count > N Then N := RightPins.Count;
    H := (N + 1) * 100;

    Component := SchServer.SchObjectFactory(eSchComponent, eCreate_GlobalCopy);
    Component.Location             := Point(MilsToCoord(X), MilsToCoord(Y));
    Component.LibReference         := RefDes + '_SELF';
    Component.ComponentDescription := Comment;
    Component.CurrentPartID        := 1;
    Component.DisplayMode          := 0;
    Component.Designator.Text      := RefDes;
    Component.Designator.Location  := Point(MilsToCoord(X), MilsToCoord(Y + 150));
    Component.Comment.Text         := Comment;
    Component.Comment.Location     := Point(MilsToCoord(X), MilsToCoord(Y + 25));

    R := SchServer.SchObjectFactory(eRectangle, eCreate_GlobalCopy);
    R.Location  := Point(MilsToCoord(X), MilsToCoord(Y - H));
    R.Corner    := Point(MilsToCoord(X + Width), MilsToCoord(Y));
    R.LineWidth := eSmall;
    R.IsSolid   := True;
    R.OwnerPartId          := 1;
    R.OwnerPartDisplayMode := 0;
    Component.AddSchObject(R);

    PinNo := 0;
    For i := 0 To LeftPins.Count - 1 Do
    Begin
        PinNo := PinNo + 1;
        Pin := SchServer.SchObjectFactory(ePin, eCreate_GlobalCopy);
        Pin.Designator  := IntToStr(PinNo);
        Pin.Name        := LeftPins[i];
        Pin.Electrical  := eElectricPassive;
        Pin.Orientation := eRotate180;
        Pin.Location    := Point(MilsToCoord(X), MilsToCoord(Y - 100 * (i + 1)));
        Pin.PinLength   := MilsToCoord(200);
        Pin.ShowName       := True;
        Pin.ShowDesignator := False;
        Pin.OwnerPartId          := 1;
        Pin.OwnerPartDisplayMode := 0;
        Component.AddSchObject(Pin);
    End;

    For i := 0 To RightPins.Count - 1 Do
    Begin
        PinNo := PinNo + 1;
        Pin := SchServer.SchObjectFactory(ePin, eCreate_GlobalCopy);
        Pin.Designator  := IntToStr(PinNo);
        Pin.Name        := RightPins[i];
        Pin.Electrical  := eElectricPassive;
        Pin.Orientation := eRotate0;
        Pin.Location    := Point(MilsToCoord(X + Width), MilsToCoord(Y - 100 * (i + 1)));
        Pin.PinLength   := MilsToCoord(200);
        Pin.ShowName       := True;
        Pin.ShowDesignator := False;
        Pin.OwnerPartId          := 1;
        Pin.OwnerPartDisplayMode := 0;
        Component.AddSchObject(Pin);
    End;

    SchDoc.RegisterSchObjectInContainer(Component);
    SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress, c_BroadCast,
        SCHM_PrimitiveRegistration, Component.I_ObjectAddress);
    Result := Component;
End;

Function MakeSchResistor(SchDoc : ISch_Document; RefDes : String; Value : String;
                         X : Integer; YTop : Integer) : ISch_Component;
Var
    Component : ISch_Component;
    R         : ISch_Rectangle;
    Pin       : ISch_Pin;
Begin
    Component := SchServer.SchObjectFactory(eSchComponent, eCreate_GlobalCopy);
    Component.Location             := Point(MilsToCoord(X), MilsToCoord(YTop));
    Component.LibReference         := 'RES_PTH_SELF';
    Component.ComponentDescription := 'PTH resistor';
    Component.CurrentPartID        := 1;
    Component.DisplayMode          := 0;
    Component.Designator.Text      := RefDes;
    Component.Designator.Location  := Point(MilsToCoord(X + 100), MilsToCoord(YTop - 250));
    Component.Comment.Text         := Value;
    Component.Comment.Location     := Point(MilsToCoord(X + 100), MilsToCoord(YTop - 400));

    R := SchServer.SchObjectFactory(eRectangle, eCreate_GlobalCopy);
    R.Location  := Point(MilsToCoord(X - 50), MilsToCoord(YTop - 450));
    R.Corner    := Point(MilsToCoord(X + 50), MilsToCoord(YTop - 150));
    R.LineWidth := eSmall;
    R.IsSolid   := True;
    R.OwnerPartId          := 1;
    R.OwnerPartDisplayMode := 0;
    Component.AddSchObject(R);

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

Procedure PcbText(Board : IPCB_Board; X, Y, SizeMil : Integer; S : String);
Var
    T : IPCB_Text;
Begin
    T := PCBServer.PCBObjectFactory(eTextObject, eNoDimension, eCreate_Default);
    T.XLocation := MilsToCoord(X);
    T.YLocation := MilsToCoord(Y);
    T.Layer     := eTopOverlay;
    T.Size      := MilsToCoord(SizeMil);
    T.Width     := MilsToCoord(8);
    T.Text      := S;
    PcbReg(Board, T);
End;

Procedure PcbTrack(Board : IPCB_Board; X1, Y1, X2, Y2, WidthMil : Integer; Layer : Integer);
Var
    Tr : IPCB_Track;
Begin
    Tr := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
    Tr.X1    := MilsToCoord(X1);
    Tr.Y1    := MilsToCoord(Y1);
    Tr.X2    := MilsToCoord(X2);
    Tr.Y2    := MilsToCoord(Y2);
    Tr.Width := MilsToCoord(WidthMil);
    Tr.Layer := Layer;
    PcbReg(Board, Tr);
End;

Procedure PcbPad(Board : IPCB_Board; X, Y : Integer; Name, NetName : String);
Var
    Pad : IPCB_Pad;
Begin
    Pad := PCBServer.PCBObjectFactory(ePadObject, eNoDimension, eCreate_Default);
    Pad.X := MilsToCoord(X);
    Pad.Y := MilsToCoord(Y);
    Pad.Name := Name;
    Pad.Layer := eMultiLayer;
    Pad.Mode := ePadMode_Simple;
    Pad.HoleSize := MilsToCoord(35);
    Pad.TopXSize := MilsToCoord(70);
    Pad.TopYSize := MilsToCoord(70);
    Pad.MidXSize := MilsToCoord(70);
    Pad.MidYSize := MilsToCoord(70);
    Pad.BotXSize := MilsToCoord(70);
    Pad.BotYSize := MilsToCoord(70);
    PcbReg(Board, Pad);
End;

Procedure Header1xN(Board : IPCB_Board; RefDes : String; X, Y, Count : Integer;
                    Nets : TStringList);
Var
    i : Integer;
Begin
    PcbText(Board, X - 60, Y + 140, 60, RefDes);
    For i := 0 To Count - 1 Do
    Begin
        PcbPad(Board, X, Y - i * 100, IntToStr(i + 1), Nets[i]);
        PcbText(Board, X + 90, Y - i * 100 - 25, 35, Nets[i]);
    End;
End;

Procedure Header2x15Esp(Board : IPCB_Board; X, Y : Integer);
Var
    i : Integer;
    L, R : TStringList;
Begin
    L := TStringList.Create;
    R := TStringList.Create;
    Try
        L.Add('VCC');     L.Add('GND');    L.Add('TX');     L.Add('RX');
        L.Add('MQ4_OUT'); L.Add('MQ7_OUT'); L.Add('HX_DT');  L.Add('HX_SCK');
        L.Add('BTN');     L.Add('GND');    L.Add('NC');     L.Add('NC');
        L.Add('NC');      L.Add('NC');     L.Add('NC');
        R.Add('SD_CS');   R.Add('SD_DI');  R.Add('SD_DO');  R.Add('SD_SCK');
        R.Add('SCL');     R.Add('SDA');    R.Add('NC');     R.Add('NC');
        R.Add('NC');      R.Add('NC');     R.Add('NC');     R.Add('NC');
        R.Add('NC');      R.Add('NC');     R.Add('GND');

        PcbText(Board, X - 80, Y + 160, 60, 'U1 ESP32-C6');
        For i := 0 To 14 Do
        Begin
            PcbPad(Board, X,       Y - i * 100, IntToStr(i + 1),  L[i]);
            PcbPad(Board, X + 600, Y - i * 100, IntToStr(i + 16), R[i]);
            If L[i] <> 'NC' Then PcbText(Board, X - 350, Y - i * 100 - 20, 35, L[i]);
            If R[i] <> 'NC' Then PcbText(Board, X + 700, Y - i * 100 - 20, 35, R[i]);
        End;
    Finally
        L.Free;
        R.Free;
    End;
End;

Procedure PthResistor(Board : IPCB_Board; RefDes, Net1, Net2 : String; X, Y : Integer);
Begin
    PcbText(Board, X - 80, Y + 120, 55, RefDes + ' 10k PTH');
    PcbPad(Board, X,       Y, '1', Net1);
    PcbPad(Board, X + 300, Y, '2', Net2);
    PcbTrack(Board, X + 60, Y, X + 240, Y, 20, eTopLayer);
End;

Procedure PushButton(Board : IPCB_Board; X, Y : Integer);
Begin
    PcbText(Board, X - 120, Y + 180, 55, 'SW1 PTH');
    PcbPad(Board, X,       Y,       '1', 'BTN');
    PcbPad(Board, X + 250, Y,       '2', 'BTN');
    PcbPad(Board, X,       Y - 250, '3', 'GND');
    PcbPad(Board, X + 250, Y - 250, '4', 'GND');
End;

Procedure RouteL(Board : IPCB_Board; X1, Y1, X2, Y2, WidthMil : Integer);
Begin
    PcbTrack(Board, X1, Y1, X2, Y1, WidthMil, eTopLayer);
    PcbTrack(Board, X2, Y1, X2, Y2, WidthMil, eTopLayer);
End;

Procedure MakeSelfContainedSchematic;
Var
    ServerDoc : IServerDocument;
    SchDoc    : ISch_Document;
    L, Rt     : TStringList;
    TextLabel : ISch_Label;
Begin
    Client.StartServer('SCH');
    ServerDoc := Client.OpenNewDocument('SCH', 'WokwiSelfContained.SchDoc', 'WokwiSelfContained.SchDoc', False);
    If ServerDoc = Nil Then Exit;
    Client.ShowDocument(ServerDoc);
    SchDoc := SchServer.GetCurrentSchDocument;
    If SchDoc = Nil Then Exit;

    L := TStringList.Create;
    Rt := TStringList.Create;
    SchServer.ProcessControl.PreProcess(SchDoc, '');
    Try
        L.Clear; Rt.Clear;
        L.Add('5V'); L.Add('RST/GND'); L.Add('TX'); L.Add('RX'); L.Add('GPIO2');
        L.Add('GPIO3'); L.Add('GPIO4'); L.Add('GPIO5'); L.Add('GPIO13'); L.Add('GND');
        Rt.Add('GPIO18'); Rt.Add('GPIO19'); Rt.Add('GPIO20'); Rt.Add('GPIO21'); Rt.Add('GPIO22'); Rt.Add('GPIO23');
        AddSchBlock(SchDoc, 'U1', 'ESP32-C6 DevKitC-1', 4200, 7000, 1200, L, Rt);
        StubH(SchDoc, 4000, 6900, -1, 'VCC');     StubH(SchDoc, 4000, 6800, -1, 'GND');
        StubH(SchDoc, 4000, 6700, -1, 'TX');      StubH(SchDoc, 4000, 6600, -1, 'RX');
        StubH(SchDoc, 4000, 6500, -1, 'MQ4_OUT'); StubH(SchDoc, 4000, 6400, -1, 'MQ7_OUT');
        StubH(SchDoc, 4000, 6300, -1, 'HX_DT');   StubH(SchDoc, 4000, 6200, -1, 'HX_SCK');
        StubH(SchDoc, 4000, 6100, -1, 'BTN');     StubH(SchDoc, 4000, 6000, -1, 'GND');
        StubH(SchDoc, 5600, 6900,  1, 'SD_CS');   StubH(SchDoc, 5600, 6800,  1, 'SD_DI');
        StubH(SchDoc, 5600, 6700,  1, 'SD_DO');   StubH(SchDoc, 5600, 6600,  1, 'SD_SCK');
        StubH(SchDoc, 5600, 6500,  1, 'SCL');     StubH(SchDoc, 5600, 6400,  1, 'SDA');

        L.Clear; Rt.Clear; Rt.Add('VCC'); Rt.Add('DT'); Rt.Add('SCK'); Rt.Add('GND');
        AddSchBlock(SchDoc, 'U2', 'HX711 50kg header', 800, 7000, 800, L, Rt);
        StubH(SchDoc, 1800, 6900, 1, 'VCC'); StubH(SchDoc, 1800, 6800, 1, 'HX_DT');
        StubH(SchDoc, 1800, 6700, 1, 'HX_SCK'); StubH(SchDoc, 1800, 6600, 1, 'GND');

        L.Clear; Rt.Clear; Rt.Add('VCC'); Rt.Add('OUT'); Rt.Add('GND');
        AddSchBlock(SchDoc, 'U3', 'MQ-7 CO header', 800, 5900, 800, L, Rt);
        StubH(SchDoc, 1800, 5800, 1, 'VCC'); StubH(SchDoc, 1800, 5700, 1, 'MQ7_OUT'); StubH(SchDoc, 1800, 5600, 1, 'GND');

        L.Clear; Rt.Clear; Rt.Add('VCC'); Rt.Add('OUT'); Rt.Add('GND');
        AddSchBlock(SchDoc, 'U4', 'MQ-4 CH4 header', 800, 4900, 800, L, Rt);
        StubH(SchDoc, 1800, 4800, 1, 'VCC'); StubH(SchDoc, 1800, 4700, 1, 'MQ4_OUT'); StubH(SchDoc, 1800, 4600, 1, 'GND');

        L.Clear; Rt.Clear; Rt.Add('1'); Rt.Add('2');
        AddSchBlock(SchDoc, 'SW1', 'PTH pushbutton', 800, 3900, 800, L, Rt);
        StubH(SchDoc, 1800, 3800, 1, 'BTN'); StubH(SchDoc, 1800, 3700, 1, 'GND');

        L.Clear; Rt.Clear; L.Add('5V'); L.Add('SCL'); L.Add('SDA'); L.Add('GND');
        AddSchBlock(SchDoc, 'U5', 'DS1307 RTC header', 7600, 7000, 800, L, Rt);
        StubH(SchDoc, 7400, 6900, -1, 'VCC'); StubH(SchDoc, 7400, 6800, -1, 'SCL');
        StubH(SchDoc, 7400, 6700, -1, 'SDA'); StubH(SchDoc, 7400, 6600, -1, 'GND');

        L.Clear; Rt.Clear; L.Add('VCC'); L.Add('SCL'); L.Add('SDA'); L.Add('GND');
        AddSchBlock(SchDoc, 'U6', 'SSD1306 OLED header', 7600, 5900, 800, L, Rt);
        StubH(SchDoc, 7400, 5800, -1, 'VCC'); StubH(SchDoc, 7400, 5700, -1, 'SCL');
        StubH(SchDoc, 7400, 5600, -1, 'SDA'); StubH(SchDoc, 7400, 5500, -1, 'GND');

        L.Clear; Rt.Clear; L.Add('VCC'); L.Add('CS'); L.Add('DI'); L.Add('DO'); L.Add('SCK'); L.Add('GND');
        AddSchBlock(SchDoc, 'U7', 'microSD SPI header', 7600, 4800, 800, L, Rt);
        StubH(SchDoc, 7400, 4700, -1, 'VCC'); StubH(SchDoc, 7400, 4600, -1, 'SD_CS');
        StubH(SchDoc, 7400, 4500, -1, 'SD_DI'); StubH(SchDoc, 7400, 4400, -1, 'SD_DO');
        StubH(SchDoc, 7400, 4300, -1, 'SD_SCK'); StubH(SchDoc, 7400, 4200, -1, 'GND');

        MakeSchResistor(SchDoc, 'R1', '10k PTH', 3400, 4800); StubV(SchDoc, 3400, 4800, 1, 'MQ4_OUT'); StubV(SchDoc, 3400, 4200, -1, 'GND');
        MakeSchResistor(SchDoc, 'R2', '10k PTH', 4200, 4800); StubV(SchDoc, 4200, 4800, 1, 'MQ7_OUT'); StubV(SchDoc, 4200, 4200, -1, 'GND');
        MakeSchResistor(SchDoc, 'R3', '10k PTH', 5000, 4800); StubV(SchDoc, 5000, 4800, 1, 'SDA');     StubV(SchDoc, 5000, 4200, -1, 'GND');
        MakeSchResistor(SchDoc, 'R4', '10k PTH', 5800, 4800); StubV(SchDoc, 5800, 4800, 1, 'SCL');     StubV(SchDoc, 5800, 4200, -1, 'GND');

        TextLabel := SchServer.SchObjectFactory(eLabel, eCreate_GlobalCopy);
        TextLabel.Location := Point(MilsToCoord(800), MilsToCoord(7500));
        TextLabel.Text     := 'Self-contained schematic; PCB is generated directly, no libraries/ECO required';
        SchReg(SchDoc, TextLabel);
    Finally
        SchServer.ProcessControl.PostProcess(SchDoc, '');
        L.Free;
        Rt.Free;
    End;
    SchDoc.GraphicallyInvalidate;
    Client.SendMessage('SCH:ZoomAllObjects', '', 255, Client.CurrentView);
End;

Procedure MakeSelfContainedPcb;
Var
    ServerDoc : IServerDocument;
    Board     : IPCB_Board;
    N         : TStringList;
Begin
    Client.StartServer('PCB');
    If PCBServer = Nil Then
    Begin
        ShowMessage('PCB server not available.');
        Exit;
    End;

    ServerDoc := Client.OpenNewDocument('PCB', 'WokwiSelfContained.PcbDoc', 'WokwiSelfContained.PcbDoc', False);
    If ServerDoc = Nil Then
    Begin
        ShowMessage('Could not create PCB document.');
        Exit;
    End;
    Client.ShowDocument(ServerDoc);
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ShowMessage('PCB document was created but could not be accessed.');
        Exit;
    End;

    PCBServer.PreProcess;
    N := TStringList.Create;
    Try
        { Board outline on keepout layer: 7400 x 5200 mil roomy starter board. }
        PcbTrack(Board, 500,  500, 7900, 500,  10, eKeepOutLayer);
        PcbTrack(Board, 7900, 500, 7900, 5700, 10, eKeepOutLayer);
        PcbTrack(Board, 7900, 5700, 500, 5700, 10, eKeepOutLayer);
        PcbTrack(Board, 500, 5700, 500, 500, 10, eKeepOutLayer);
        PcbText(Board, 700, 5450, 70, 'Wokwi self-contained carrier PCB - spaced placement');

        Header2x15Esp(Board, 3900, 5000);

        N.Clear; N.Add('VCC'); N.Add('HX_DT'); N.Add('HX_SCK'); N.Add('GND');
        Header1xN(Board, 'U2 HX711', 1000, 5000, 4, N);
        N.Clear; N.Add('VCC'); N.Add('MQ7_OUT'); N.Add('GND'); N.Add('NC');
        Header1xN(Board, 'U3 MQ7', 1000, 3800, 4, N);
        N.Clear; N.Add('VCC'); N.Add('MQ4_OUT'); N.Add('GND'); N.Add('NC');
        Header1xN(Board, 'U4 MQ4', 1000, 2600, 4, N);

        N.Clear; N.Add('VCC'); N.Add('SCL'); N.Add('SDA'); N.Add('GND');
        Header1xN(Board, 'U5 RTC', 7000, 5000, 4, N);
        N.Clear; N.Add('VCC'); N.Add('SCL'); N.Add('SDA'); N.Add('GND');
        Header1xN(Board, 'U6 OLED', 7000, 3800, 4, N);
        N.Clear; N.Add('VCC'); N.Add('SD_CS'); N.Add('SD_DI'); N.Add('SD_DO'); N.Add('SD_SCK'); N.Add('GND');
        Header1xN(Board, 'U7 SD', 7000, 2400, 6, N);

        PthResistor(Board, 'R1', 'MQ4_OUT', 'GND', 1800, 1200);
        PthResistor(Board, 'R2', 'MQ7_OUT', 'GND', 3000, 1200);
        PthResistor(Board, 'R3', 'SDA',     'GND', 4200, 1200);
        PthResistor(Board, 'R4', 'SCL',     'GND', 5400, 1200);
        PushButton(Board, 1000, 1200);

        { Main signal routes. Endpoints match the pad coordinates created above. }
        RouteL(Board, 3900, 5000, 1000, 5000, 20); { VCC: ESP32 -> HX711 }
        RouteL(Board, 3900, 5000, 1000, 3800, 20); { VCC: ESP32 -> MQ7 }
        RouteL(Board, 3900, 5000, 1000, 2600, 20); { VCC: ESP32 -> MQ4 }
        RouteL(Board, 3900, 5000, 7000, 5000, 20); { VCC: ESP32 -> RTC }
        RouteL(Board, 3900, 5000, 7000, 3800, 20); { VCC: ESP32 -> OLED }
        RouteL(Board, 3900, 5000, 7000, 2400, 20); { VCC: ESP32 -> SD }

        RouteL(Board, 3900, 4900, 1000, 4700, 20); { GND: ESP32 -> HX711 }
        RouteL(Board, 3900, 4900, 1000, 3600, 20); { GND: ESP32 -> MQ7 }
        RouteL(Board, 3900, 4900, 1000, 2400, 20); { GND: ESP32 -> MQ4 }
        RouteL(Board, 3900, 4900, 7000, 4700, 20); { GND: ESP32 -> RTC }
        RouteL(Board, 3900, 4900, 7000, 3500, 20); { GND: ESP32 -> OLED }
        RouteL(Board, 3900, 4900, 7000, 1900, 20); { GND: ESP32 -> SD }
        RouteL(Board, 3900, 4900, 2100, 1200, 20); { GND: ESP32 -> R1 }
        RouteL(Board, 3900, 4900, 3300, 1200, 20); { GND: ESP32 -> R2 }
        RouteL(Board, 3900, 4900, 4500, 1200, 20); { GND: ESP32 -> R3 }
        RouteL(Board, 3900, 4900, 5700, 1200, 20); { GND: ESP32 -> R4 }
        RouteL(Board, 3900, 4900, 1000, 950, 20);  { GND: ESP32 -> SW1 }

        RouteL(Board, 3900, 4400, 1000, 4900, 12); { HX_DT }
        RouteL(Board, 3900, 4300, 1000, 4800, 12); { HX_SCK }
        RouteL(Board, 3900, 4500, 1000, 3700, 12); { MQ7_OUT -> MQ7 }
        RouteL(Board, 3900, 4500, 3000, 1200, 12); { MQ7_OUT -> R2 }
        RouteL(Board, 3900, 4600, 1000, 2500, 12); { MQ4_OUT -> MQ4 }
        RouteL(Board, 3900, 4600, 1800, 1200, 12); { MQ4_OUT -> R1 }
        RouteL(Board, 3900, 4200, 1000, 1200, 12); { BTN -> SW1 }

        RouteL(Board, 4500, 5000, 7000, 2300, 12); { SD_CS }
        RouteL(Board, 4500, 4900, 7000, 2200, 12); { SD_DI }
        RouteL(Board, 4500, 4800, 7000, 2100, 12); { SD_DO }
        RouteL(Board, 4500, 4700, 7000, 2000, 12); { SD_SCK }
        RouteL(Board, 4500, 4600, 7000, 4900, 12); { SCL -> RTC }
        RouteL(Board, 4500, 4600, 7000, 3700, 12); { SCL -> OLED }
        RouteL(Board, 4500, 4600, 5400, 1200, 12); { SCL -> R4 }
        RouteL(Board, 4500, 4500, 7000, 4800, 12); { SDA -> RTC }
        RouteL(Board, 4500, 4500, 7000, 3600, 12); { SDA -> OLED }
        RouteL(Board, 4500, 4500, 4200, 1200, 12); { SDA -> R3 }

        PcbText(Board, 700, 650, 45, 'Generated pads/tracks only. Verify pinout, clearances, and routing before fabrication.');
    Finally
        N.Free;
        PCBServer.PostProcess;
    End;

    Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);
End;

Procedure MakeWokwiSelfContainedPcb;
Begin
    MakeSelfContainedSchematic;
    MakeSelfContainedPcb;
    ShowMessage('Created WokwiSelfContained.SchDoc and WokwiSelfContained.PcbDoc. No external footprints or libraries were used.');
End;
