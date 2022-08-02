unit Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.SvcMgr, Vcl.Dialogs,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client,
  FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt,
  FireDAC.Comp.DataSet, frxClass, System.StrUtils,
  FRPrinter, FRPrinter.Types, Utils, Data, Horse;

type
  TsrvFastReportPrintHorse = class(TService)
    procedure ServiceStart(Sender: TService; var Started: Boolean);
  private
    { Private declarations }
    procedure PrintFastReport(pReq: THorseRequest; pRes: THorseResponse; pNext: TNextProc);
  public
    { Public declarations }
    function GetServiceController: TServiceController; override;
  end;

var
  srvFastReportPrintHorse: TsrvFastReportPrintHorse;

implementation

{$R *.dfm}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  srvFastReportPrintHorse.Controller(CtrlCode);
end;

procedure TsrvFastReportPrintHorse.PrintFastReport(pReq: THorseRequest;
  pRes: THorseResponse; pNext: TNextProc);
var
  lFDConnection: TFDConnection;
  lQryEstadosBrasil: TFDQuery;
  lQryMunicipioEstado: TFDQuery;
  lQryMunicipioRegiao: TFDQuery;
  lQryEstadoRegiao: TFDQuery;
  lQryMunicipios: TFDQuery;
  lError: string;
  lFiltro: Integer;
  lPrinted: Boolean;
begin
  lFiltro := pReq.Params.Field('estadoid').AsInteger;
  lFDConnection := nil;
  try
    lFDConnection := TFDConnection.Create(nil);

    //CONEX�O COM O BANCO DE DADOS DE EXEMPLO
    if not TUtils.ConnectDB('127.0.0.1', TUtils.PathAppFileDB, lFDConnection, lError) then
    begin
      pRes.Send('Erro de conex�o: ' + lError).Status(500);
      Exit;
    end;

    //CONSULTA BANCO DE DADOS
    try
      TData.QryEstadosBrasil(lFDConnection, lQryEstadosBrasil);
      TData.QryMunicipioEstado(lFDConnection, lQryMunicipioEstado);
      TData.QryMunicipioRegiao(lFDConnection, lQryMunicipioRegiao);
      TData.QryEstadoRegiao(lFDConnection, lQryEstadoRegiao);
      TData.QryMunicipios(lFDConnection, lQryMunicipios, lFiltro);
    except
      on E: Exception do
      begin
        pRes.Send(E.Message).Status(500);
        Exit;
      end;
    end;

    //CLASSE DE IMPRESS�O
    try
      lPrinted := TFRPrinter.New.
      DataSets.
        SetDataSet(lQryEstadosBrasil, 'EstadosBrasil').
        SetDataSet(lQryMunicipioEstado, 'MunicipioEstado').
        SetDataSet(lQryMunicipioRegiao, 'MunicipioRegiao').
        SetDataSet(lQryEstadoRegiao, 'EstadoRegiao').
        SetDataSet(lQryMunicipios, 'Municipios').
      &End.
      Print.
        //SetPrinter('Microsoft Print to PDF'). //QUANDO N�O INFORMADO UTILIZA A IMPRESSORA CONFIGURADA NO RELAT�RIO *.fr3
        SetExceptionFastReport(True).
        SetFileReport(TUtils.PathAppFileReport). //LOCAL DO RELAT�RIO *.fr3
        Report(procedure(pfrxReport: TfrxReport) //CONFIGURA��O DO COMPONENTE DE RELAT�RIO DO FAST REPORT
        var
          lfrxComponent: TfrxComponent;
          lfrxMemoView: TfrxMemoView absolute lfrxComponent;
        begin
          //CONFIGURA��O DO COMPONENTE

          pfrxReport.ReportOptions.Name := 'API de localidades IBGE'; //NOME PARA IDENTIFICA��O NA IMPRESS�O DO RELAT�RIO
          pfrxReport.ReportOptions.Author := 'Ant�nio Jos� Medeiros Schneider';

          //PASSAGEM DE PAR�METRO PARA O RELAT�RIO
          lfrxComponent := pfrxReport.FindObject('mmoProcess');
          if Assigned(lfrxComponent) then
          begin
            lfrxMemoView.Memo.Clear;
            lfrxMemoView.Memo.Text := Format('Aplicativo de Exemplo: %s', ['WINDOWS SERVER HORSE']);
          end;
        end).
        Execute; //PROCESSAMENTO DO RELAT�RIO/IMPRESS�O
    except
      on E: Exception do
      begin
        if E is EFRPrinter then
          pRes.Send(E.ToString).Status(500)
        else
          pRes.Send(E.Message+' - '+E.QualifiedClassName).Status(500);
        Exit;
      end;
    end;

    if lPrinted then
      pRes.Send('Impresso').Status(200)
    else
      pRes.Send('Falha de impress�o').Status(500);
  finally
    lFDConnection.Free;
  end;
end;

function TsrvFastReportPrintHorse.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TsrvFastReportPrintHorse.ServiceStart(Sender: TService;
  var Started: Boolean);
begin
  Started := True;
  ReportStatus;

  THorse.MaxConnections := 100;

  THorse.Get('ping',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      Res.Send('pong');
    end);

  //CERTO � POST, MAS COMO EXEMPLO PARA VISUALIZAR NO BROWSER VAI SER O GET
  THorse.Get('print/:estadoid', PrintFastreport);

  THorse.Listen(9002);

  Sleep(1000);
end;

end.
