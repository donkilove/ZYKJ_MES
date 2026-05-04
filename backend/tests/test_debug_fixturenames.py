"""Debug test for fixturenames at class scope."""
import sys, os
sys.path.insert(0, 'C:/Users/Donki/Desktop/ZYKJ_MES/backend')
os.chdir('C:/Users/Donki/Desktop/ZYKJ_MES/backend')

import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.api import deps


class TestDebugFixtureIntegration:
    @pytest.fixture(scope="class", autouse=True)
    def check_class_fixtures(self, request):
        print(f"\nCLASS FIXTURE fixturenames: {request.fixturenames}")
        yield

    def test_debug(self, client):
        print(f"TEST fixturenames: {client.__class__.__name__}")
        assert True
