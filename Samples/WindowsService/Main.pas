unit Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.SvcMgr, Vcl.Dialogs,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client,
  FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt,
  FireDAC.Comp.DataSet, frxClass,
  FRPrinter, FRPrinter.Interfaces, FRPrinter.Types,
  Utils, Data;

type
  TsrvFastReportPrint = class(TService)
    procedure ServiceStart(Sender: TService; var Started: Boolean);
  private
    { Private declarations }
  public
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end;

var
  srvFastReportPrint: TsrvFastReportPrint;

implementation

{$R *.dfm}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  srvFastReportPrint.Controller(CtrlCode);
end;

function TsrvFastReportPrint.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TsrvFastReportPrint.ServiceStart(Sender: TService; var Started: Boolean);
var
  lFDConnection: TFDConnection;
  lQryEstadosBrasil: TFDQuery;
  lQryMunicipioEstado: TFDQuery;
  lQryMunicipioRegiao: TFDQuery;
  lQryEstadoRegiao: TFDQuery;
  lQryMunicipios: TFDQuery;
  lError: string;
  lPrinted: Boolean;
begin
  Started := True;
  ReportStatus;

  Sleep(1000);

  LogMessage('Impress�o Fast Report.', EVENTLOG_INFORMATION_TYPE, 0, 1050);

  lFDConnection := nil;
  try
    lFDConnection := TFDConnection.Create(nil);

    //CONEX�O COM O BANCO DE DADOS DE EXEMPLO
    if not TUtils.ConnectDB('127.0.0.1', TUtils.PathAppFileDB, lFDConnection, lError) then
    begin
      LogMessage('Erro de conex�o: ' + lError, EVENTLOG_ERROR_TYPE, 0, 1050);
      Exit;
    end;

    //CONSULTA BANCO DE DADOS
    try
      TData.QryEstadosBrasil(lFDConnection, lQryEstadosBrasil);
      TData.QryMunicipioEstado(lFDConnection, lQryMunicipioEstado);
      TData.QryMunicipioRegiao(lFDConnection, lQryMunicipioRegiao);
      TData.QryEstadoRegiao(lFDConnection, lQryEstadoRegiao);
      TData.QryMunicipios(lFDConnection, lQryMunicipios);
    except
      on E: Exception do
      begin
        LogMessage(E.Message, EVENTLOG_ERROR_TYPE, 0, 1050);
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
            lfrxMemoView.Memo.Text := Format('Aplicativo de Exemplo: %s', ['WINDOWS SERVICE']);
          end;
        end).
        Execute; //PROCESSAMENTO DO RELAT�RIO/IMPRESS�O
    except
      on E: Exception do
      begin
        if E is EFRPrinter then
          LogMessage('Erro de impress�o: ' + E.ToString, EVENTLOG_ERROR_TYPE, 0, 1050)
        else
          LogMessage('Erro de impress�o: ' + E.Message, EVENTLOG_ERROR_TYPE, 0, 1050);
        Exit;
      end;
    end;

    if lPrinted then
      LogMessage('Relat�rio impresso com sucesso.', EVENTLOG_INFORMATION_TYPE, 0, 1050)
    else
      LogMessage('Relat�rio falha de impress�o.', EVENTLOG_INFORMATION_TYPE, 0, 1050);

  finally
    lFDConnection.Free;
  end;
end;

end.
