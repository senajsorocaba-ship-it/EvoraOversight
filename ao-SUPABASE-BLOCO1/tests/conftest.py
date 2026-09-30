"""Deixa os scripts de ao-SUPABASE-BLOCO1/ importáveis pelos testes.

Eles são scripts soltos (não um pacote instalável) — sem isto, `import
extrator_veritas` de dentro de tests/ falharia com ModuleNotFoundError.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
