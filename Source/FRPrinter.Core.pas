{******************************************************************************}
{                                                                              }
{           FRPrinter.Core                                                     }
{                                                                              }
{           Copyright (C) Ant�nio Jos� Medeiros Schneider J�nior               }
{                                                                              }
{           https://github.com/antoniojmsjr/FastReportPrinter                  }
{                                                                              }
{                                                                              }
{******************************************************************************}
{                                                                              }
{  Licensed under the Apache License, Version 2.0 (the "License");             }
{  you may not use this file except in compliance with the License.            }
{  You may obtain a copy of the License at                                     }
{                                                                              }
{      http://www.apache.org/licenses/LICENSE-2.0                              }
{                                                                              }
{  Unless required by applicable law or agreed to in writing, software         }
{  distributed under the License is distributed on an "AS IS" BASIS,           }
{  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.    }
{  See the License for the specific language governing permissions and         }
{  limitations under the License.                                              }
{                                                                              }
{******************************************************************************}
unit FRPrinter.Core;

interface

uses
  System.Classes, System.Generics.Collections, System.Win.ComObj, Vcl.ExtCtrls,
  frxClass, frxDBSet, frxExportPDF, frxExportHTML, frxExportImage, frxExportCSV,
  frxExportRTF, frxChart, frxBarcode, frxOLE, frxRich, frxCross,
  frxGradient, frxDMPExport, frxCrypt, frxChBox,

  //ESSA LINHA PODE SER COMENTADA QUANDO A VERS�O DO FAST REPORT N�O D� SUPORTE
  frxGaugeView, frxMap, frxCellularTextObject, frxZipCode, frxTableObject, frxGaugePanel,
  frxADOComponents, frxDBXComponents, frxIBXComponents,

  Data.DB, FRPrinter.Types, FRPrinter.Interfaces;

type
  TFRPrinterDataSets = class;
  TFRPrinterExecute = class;

  {$REGION 'TFRPrinterCustom'}
  TFRPrinterCustom = class(TInterfacedObject, IFRPrinter)
  private
    { private declarations }
    FFrxReport: TfrxReport;
    FFRPrinterDataSetsInterf: IFRPrinterDataSets;
    FFRPrinterExecuteInterf: IFRPrinterExecute;

    function GetFRPrintertDataSets: IFRPrinterDataSets;
    function GetFRPrinterExecute: IFRPrinterExecute;
  protected
    { protected declarations }
  public
    { public declarations }
    constructor Create;
    destructor Destroy; override;
  end;
  {$ENDREGION}

  {$REGION 'TFRPrinterDataSets'}
  TFRPrinterDataSets = class sealed(TInterfacedObject, IFRPrinterDataSets)
  private
    { private declarations }
    [Weak] //N�O INCREMENTA O CONTADOR DE REFER�NCIA
    FParent: IFRPrinter;
    FFrxReport: TfrxReport;
    FListFrxDBDataset: TObjectList<TfrxDBDataset>;
    function GetEnd: IFRPrinter;
    function SetDataSet(pDataSet: TDataSet; const pUserName: string): IFRPrinterDataSets; overload;
    function SetDataSet(pDataSet: TfrxDBDataset): IFRPrinterDataSets; overload;
  protected
    { protected declarations }
  public
    { public declarations }
    constructor Create(pParent: IFRPrinter; pFrxReport: TfrxReport);
    destructor Destroy; override;
  end;
  {$ENDREGION}

  {$REGION 'TFRPrinterExecuteCustom'}
  TFRPrinterExecuteCustom = class(TInterfacedObject, IFRPrinterExecute)
  private
    { private declarations }
    FExceptionFastReport: Boolean;
    FPrinterName: string;
    function SetExceptionFastReport(const pValue: Boolean): IFRPrinterExecute;
    function SetPrinter(const pPrinterName: string): IFRPrinterExecute;
    function SetFileReport(const pFileName: string): IFRPrinterExecute; overload;
    function SetFileReport(pFileStream: TStream): IFRPrinterExecute; overload;
    function Report(const pCallbackReport: TFRPrinterReportCallback): IFRPrinterExecute;
    function Execute: Boolean; virtual; abstract;
    procedure ConfigReportComponent;
  protected
    { protected declarations }
    FFrxReport: TfrxReport;
  public
    { public declarations }
    constructor Create(pFrxReport: TfrxReport);
  end;
  {$ENDREGION}

  {$REGION 'TFRPrinterExecute'}
  TFRPrinterExecute = class sealed(TFRPrinterExecuteCustom)
  private
    { private declarations }
    function Execute: Boolean; override;
  protected
    { protected declarations }
  public
    { public declarations }
  end;
  {$ENDREGION}

implementation

uses
  System.SysUtils, frxPrinter;

{$REGION 'TFRPrinterCustom'}
constructor TFRPrinterCustom.Create;
begin
  FFrxReport := TfrxReport.Create(nil);

  FFRPrinterDataSetsInterf := TFRPrinterDataSets.Create(Self, FFrxReport);
  FFRPrinterExecuteInterf := TFRPrinterExecute.Create(FFrxReport);
end;

destructor TFRPrinterCustom.Destroy;
begin
  FFrxReport.Free;
  inherited Destroy;
end;

function TFRPrinterCustom.GetFRPrintertDataSets: IFRPrinterDataSets;
begin
  Result := FFRPrinterDataSetsInterf;
end;

function TFRPrinterCustom.GetFRPrinterExecute: IFRPrinterExecute;
begin
  Result := FFRPrinterExecuteInterf;
end;
{$ENDREGION}

{$REGION 'TFRPrinterDataSets'}
constructor TFRPrinterDataSets.Create(pParent: IFRPrinter;
  pFrxReport: TfrxReport);
begin
  FParent := pParent;
  {$IF COMPILERVERSION <= 30} //Delphi 10 Seattle / C++Builder 10 Seattle
  FParent._Release;
  {$ENDIF}

  FFrxReport := pFrxReport;
  FFrxReport.DataSets.Clear;
  FFrxReport.EnabledDataSets.Clear;

  FListFrxDBDataset := TObjectList<TfrxDBDataset>.Create(True);
end;

destructor TFRPrinterDataSets.Destroy;
begin
  FListFrxDBDataset.Clear;
  FListFrxDBDataset.Free;
  inherited Destroy;
end;

function TFRPrinterDataSets.GetEnd: IFRPrinter;
begin
  Result := FParent;
end;

function TFRPrinterDataSets.SetDataSet(
  pDataSet: TfrxDBDataset): IFRPrinterDataSets;
begin
  Result := Self;

  FFrxReport.EnabledDataSets.Add(pDataSet);
end;

//pUserName: Um nome simb�lico, sob o qual o conjunto de dados ser� exibido no designer de cria��o do relat�rio.
function TFRPrinterDataSets.SetDataSet(pDataSet: TDataSet;
  const pUserName: string): IFRPrinterDataSets;
var
  lFrxDBDataset: TfrxDBDataset;
begin
  Result := Self;

  lFrxDBDataset := TfrxDBDataset.Create(nil);
  if (Trim(pDataSet.Name) <> EmptyStr) then
    lFrxDBDataset.Name := Format('frxDB%s', [pDataSet.Name])
  else
    lFrxDBDataset.Name := Format('frxDB%s', [pUserName]);

  lFrxDBDataset.CloseDataSource := False;
  lFrxDBDataset.OpenDataSource := False;
  lFrxDBDataset.UserName := pUserName;
  lFrxDBDataset.DataSet := pDataSet;

  FListFrxDBDataset.Add(lFrxDBDataset);
  FFrxReport.EnabledDataSets.Add(lFrxDBDataset);
end;
{$ENDREGION}

{$REGION 'TFRPrinterExecuteCustom'}
constructor TFRPrinterExecuteCustom.Create(pFrxReport: TfrxReport);
begin
  FFrxReport := pFrxReport;

  ConfigReportComponent;
end;

procedure TFRPrinterExecuteCustom.ConfigReportComponent;
begin
  //A classe TfrxEngineOptions representa um conjunto de propriedades relacionadas ao mecanismo FastReport. A inst�ncia desta classe � armazenada no TfrxReport.EngineOptions

  //Define se o relat�rio � matricial. Ao definir esta propriedade como True, o relat�rio pode conter p�ginas matriciais (TfrxDMPPage) e objetos. N�o defina esta propriedade diretamente. Use o item de menu "Arquivo|Novo..." para criar relat�rios matriciais.
  //FFrxReport.DotMatrixReport := False;

  FFrxReport.EngineOptions.Clear;

  //Alterne o componente TfrxReport no modo multithread. Desabilita rotinas inseguras como o ciclo ProcessMessages.
  FFrxReport.EngineOptions.EnableThreadSafe := True;

  //Determina se o relat�rio deve ser salvo no fluxo tempor�rio antes de executar um relat�rio e restaur�-lo ap�s a conclus�o do relat�rio. O padr�o � Verdadeiro.
  FFrxReport.EngineOptions.DestroyForms := False;

  //A propriedade determina se � necess�rio utilizar a lista global de DataSet ou a lista de cole��o EnabledDataSet do componente TfrxReport. Padr�o-Verdadeiro.
  FFrxReport.EngineOptions.UseGlobalDataSetList := False;

  //Define se � necess�rio usar o cache de p�ginas de relat�rio em um arquivo (consulte a propriedade "MaxMemSize"). O valor padr�o � Falso.
  FFrxReport.EngineOptions.UseFileCache := False;

  //O tamanho m�ximo de mem�ria em Mbytes, alocado para o cache das p�ginas do relat�rio. Torna-se �til nos casos em que a propriedade "UseFileCache" � igual a "True". Se um relat�rio come�ar a ocupar mais mem�ria durante a constru��o, o cache das p�ginas de relat�rio constru�das em um arquivo tempor�rio � executado. Esta propriedade � inexata e permite apenas a determina��o aproximada do limite de mem�ria. O valor padr�o � 10.
  //FFrxReport.EngineOptions.MaxMemSize

  //Preterido (consulte NewSilentMode). "Modo silencioso. Quando ocorrerem erros durante o carregamento ou execu��o do relat�rio, nenhuma janela de di�logo ser� exibida.
  //Todos os erros estar�o contidos no TfrxReport. Propriedade de erros. Este modo � �til para aplicativos de servidor. O valor padr�o � Falso.
  //FFastReport.EngineOptions.SilentMode := True;

  //Defina o comportamento do tratamento de exce��es durante a execu��o do relat�rio.
  FFrxReport.EngineOptions.NewSilentMode := simSilent;
  if FExceptionFastReport then
    FFrxReport.EngineOptions.NewSilentMode := simReThrow;

  FFrxReport.Preview := nil;
  FFrxReport.PreviewOptions.AllowEdit := False;
  FFrxReport.ShowProgress := False;
  FFrxReport.StoreInDFM := False;
  FFrxReport.ScriptLanguage := 'PascalScript';
end;

function TFRPrinterExecuteCustom.Report(
  const pCallbackReport: TFRPrinterReportCallback): IFRPrinterExecute;
begin
  Result := Self;

  if Assigned(pCallbackReport) then
    pCallbackReport(FFrxReport);
end;

function TFRPrinterExecuteCustom.SetExceptionFastReport(
  const pValue: Boolean): IFRPrinterExecute;
begin
  Result := Self;

  FExceptionFastReport := pValue;
end;

function TFRPrinterExecuteCustom.SetFileReport(
  pFileStream: TStream): IFRPrinterExecute;
begin
  Result := Self;

  //CARREGA O ARQUIVO DE RELAT�RIO
  try
    FFrxReport.LoadFromStream(pFileStream);
  except
    on E: Exception do
      raise EFRPrinterFileReport.Create('File Stream', E.Message);
  end;
end;

function TFRPrinterExecuteCustom.SetPrinter(
  const pPrinterName: string): IFRPrinterExecute;
begin
  Result := Self;

  FPrinterName := pPrinterName.Trim;
end;

function TFRPrinterExecuteCustom.SetFileReport(
  const pFileName: string): IFRPrinterExecute;
begin
  Result := Self;

  if pFileName.Trim.IsEmpty then
    raise EFRPrinterFileReport.Create(pFileName, 'File is empty.');

  if not FileExists(pFileName) then
    raise EFRPrinterFileReport.Create(pFileName, 'File not found.');

  //CARREGA O ARQUIVO DE RELAT�RIO
  try
    FFrxReport.LoadFromFile(pFileName);
  except
    on E: Exception do
      raise EFRPrinterFileReport.Create(pFileName, E.Message);
  end;
end;
{$ENDREGION}

{$REGION 'TFRPrinterExecute'}
function TFRPrinterExecute.Execute: Boolean;
begin
  Sleep(1);

  if (FPrinterName <> EmptyStr) then
    FFrxReport.PrintOptions.Printer := FPrinterName;

  if not SameText(FFrxReport.PrintOptions.Printer, 'Default') then
    if (frxPrinters.IndexOf(FFrxReport.PrintOptions.Printer) < 0) then
      raise EFRPrinterPrint.Create(FFrxReport.PrintOptions.Printer, 'Printer not found.');

  FFrxReport.PrintOptions.ShowDialog := False;
  FFrxReport.PrintOptions.Collate := True;
  FFrxReport.PrintOptions.Copies := 1;

  //PREPARE REPORT
  if not FFrxReport.PrepareReport(False) then
    raise EFRPrinterPrepareReport.Create(FFrxReport.Errors); //PEGA OS ERROS GERADO PELO PrepareReport

  //PRINTER
  Result := FFrxReport.Print;

  if Result then
    if not frxPrinters.Printer.Initialized then //FALHA DocumentProperties - CreateDevMode - frxPrinter.pas
      raise EFRPrinterPrint.Create(FFrxReport.PrintOptions.Printer, 'Printer selected is not valid.');
end;
{$ENDREGION}

end.
