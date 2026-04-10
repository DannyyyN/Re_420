for /R ".\" %%f in (*.lua) do xcopy "%%f" "..\..\..\..\..\Assets\InbetweenArrows\Re_420\RailVehicles\Re_420_3S" /Y
cd "..\..\..\..\..\Assets\InbetweenArrows\Re_420\RailVehicles\Re_420_3S"
del Re_420_EngineScript.out
del Re_420_EngineScript.out.tgt
