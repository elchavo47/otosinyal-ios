#!/usr/bin/env python3
"""Recover deterministic VAG assets from the user's legacy application build.

The old ShiftStream2 transform and BSON payload layout have been reconstructed.
This tool normalizes the recovered adaptation databases to JSON without editing
the original bytes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def find_one(resources: Path, suffix: str) -> Path:
    matches = list(resources.glob(f"*{suffix}"))
    if len(matches) != 1:
        raise FileNotFoundError(f"Expected one '*{suffix}', found {len(matches)}")
    return matches[0]


def shift_stream2(raw: bytes) -> bytes:
    out = bytearray(len(raw))
    for i, value in enumerate(raw):
        if i % 2 == 0:
            out[i] = (value - 88 - (i & 0xFF)) & 0xFF
        else:
            out[i] = (value + 69 + (i & 0xFF)) & 0xFF
    return bytes(out)


def _cstring(data: bytes, offset: int) -> tuple[str, int]:
    end = data.index(0, offset)
    return data[offset:end].decode('utf-8', errors='replace'), end + 1


def _bson_document(data: bytes, offset: int = 0, as_array: bool = False):
    start = offset
    length = struct.unpack_from('<i', data, offset)[0]
    end = start + length
    offset += 4
    result: dict[str, object] = {}
    while offset < end - 1:
        kind = data[offset]
        offset += 1
        key, offset = _cstring(data, offset)
        if kind == 0x01:
            value = struct.unpack_from('<d', data, offset)[0]; offset += 8
        elif kind == 0x02:
            size = struct.unpack_from('<i', data, offset)[0]; offset += 4
            value = data[offset:offset + size - 1].decode('utf-8', errors='replace'); offset += size
        elif kind == 0x03:
            value, offset = _bson_document(data, offset, False)
        elif kind == 0x04:
            value, offset = _bson_document(data, offset, True)
        elif kind == 0x05:
            size = struct.unpack_from('<i', data, offset)[0]; offset += 4
            subtype = data[offset]; offset += 1
            value = {'$binary': data[offset:offset + size].hex(), '$subtype': subtype}; offset += size
        elif kind == 0x08:
            value = bool(data[offset]); offset += 1
        elif kind == 0x09:
            value = {'$date': struct.unpack_from('<q', data, offset)[0]}; offset += 8
        elif kind == 0x0A:
            value = None
        elif kind == 0x10:
            value = struct.unpack_from('<i', data, offset)[0]; offset += 4
        elif kind == 0x12:
            value = struct.unpack_from('<q', data, offset)[0]; offset += 8
        else:
            raise ValueError(f'Unsupported BSON type 0x{kind:02X} at {offset - 1} ({key})')
        result[key] = value
    if data[end - 1] != 0:
        raise ValueError('Malformed BSON terminator')
    if as_array:
        try:
            return [result[str(i)] for i in range(len(result))], end
        except KeyError:
            return list(result.values()), end
    return result, end


def parse_shift2_bson(path: Path) -> list[dict[str, object]]:
    decoded = shift_stream2(path.read_bytes())
    value, end = _bson_document(decoded, 0, True)
    if end != len(decoded):
        raise ValueError(f'{path.name}: BSON ended at {end}, file has {len(decoded)} bytes')
    return value


def parse_vag_dtc(path: Path) -> list[dict[str, object]]:
    data = path.read_bytes()
    if len(data) < 4:
        raise ValueError("VAG.db too short")
    declared = struct.unpack_from("<I", data, 0)[0]
    if declared != len(data):
        raise ValueError(f"VAG.db size header {declared} != actual {len(data)}")

    out: list[dict[str, object]] = []
    offset = 4
    while offset < len(data):
        # The recovered build has a final zero sentinel after the last record.
        if offset == len(data) - 1 and data[offset] == 0:
            offset += 1
            break

        marker = data[offset]
        offset += 1
        code_end = data.find(b"\0", offset)
        if code_end < 0:
            raise ValueError(f"Missing DTC code terminator at {offset}")
        code = data[offset:code_end].decode("ascii", errors="strict")
        offset = code_end + 1

        if offset + 4 > len(data):
            raise ValueError("Unexpected EOF before DTC description length")
        length = struct.unpack_from("<I", data, offset)[0]
        offset += 4
        end = offset + length
        if end > len(data):
            raise ValueError(f"DTC description overrun for {code}")
        description = data[offset:end].rstrip(b"\0").decode("utf-8", errors="replace")
        offset = end
        out.append({"code": code, "description": description, "marker": marker})

    if offset != len(data):
        raise ValueError("DTC parser did not finish at EOF")
    return out


def ascii_strings(path: Path, minimum: int = 4) -> list[str]:
    data = path.read_bytes()
    result: list[str] = []
    buf: list[str] = []
    for value in data:
        if 32 <= value < 127:
            buf.append(chr(value))
        else:
            if len(buf) >= minimum:
                result.append("".join(buf))
            buf = []
    if len(buf) >= minimum:
        result.append("".join(buf))
    return result


def write_json(path: Path, obj: object, pretty: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(
            obj,
            ensure_ascii=False,
            indent=2 if pretty else None,
            separators=None if pretty else (",", ":"),
        ),
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("recovery_dir", type=Path, help="Directory containing assemblies/ and resources/")
    parser.add_argument("output_dir", type=Path, help="Output assets directory")
    parser.add_argument("--source-zip", type=Path)
    args = parser.parse_args()

    resources = args.recovery_dir / "resources"
    assemblies = args.recovery_dir / "assemblies"
    out = args.output_dir

    dtc_path = find_one(resources, "dtcdb.VAG.db")
    dtc_records = parse_vag_dtc(dtc_path)
    write_json(out / "vag_dtc_catalog_v1.json", {
        "schemaVersion": 1,
        "source": dtc_path.name,
        "sourceSha256": sha256(dtc_path),
        "recordCount": len(dtc_records),
        "records": dtc_records,
    })

    plain = {
        "vagplatforms.db": "vag_platforms_v1.json",
        "mqb_light_functions": "mqb_light_functions_v1.json",
        "mqb_light_types": "mqb_light_types_v1.json",
    }
    decoded_counts: dict[str, int] = {"vagDtcRecords": len(dtc_records)}
    key_map = {
        "vagplatforms.db": "platformRecords",
        "mqb_light_functions": "mqbLightFunctionRecords",
        "mqb_light_types": "mqbLightTypeRecords",
    }
    for suffix, output_name in plain.items():
        source = find_one(resources, suffix)
        records = json.loads(source.read_text(encoding="utf-8-sig"))
        write_json(out / output_name, {
            "schemaVersion": 1,
            "source": source.name,
            "sourceSha256": sha256(source),
            "recordCount": len(records),
            "records": records,
        })
        decoded_counts[key_map[suffix]] = len(records)

    adaptation_sources = {
        "MQB": "mqbadaptations.db",
        "PQ26": "pq26adaptations.db",
        "PQ26-NEW-RAPID-2020": "pq26newrapid2020.db",
        "PQ35": "pq35adaptations.db",
        "MLB-A4B9": "a4b9adaptations.db",
        "MEB": "vagmeb.db",
        "MQB-CAMERA-FUSION": "mqb_camera_fusion.db",
        "MQB-SWAP-CUSTOM-CODING": "mqb_swap_custom_coding.db",
    }
    adaptation_catalogs: list[dict[str, object]] = []
    for platform, suffix in adaptation_sources.items():
        matches = list(resources.glob(f"*{suffix}"))
        if not matches:
            continue
        source = matches[0]
        records = parse_shift2_bson(source)
        output_name = "recovered_" + platform.lower().replace("-", "_") + "_adaptations_v1.json"
        write_json(out / output_name, {
            "schemaVersion": 1,
            "platform": platform,
            "source": source.name,
            "sourceSha256": sha256(source),
            "decoder": "legacy ShiftStream2 + BSON",
            "records": records,
        })
        adaptation_catalogs.append({
            "platform": platform,
            "file": output_name,
            "records": len(records),
            "sha256": sha256(source),
        })
    write_json(out / "adaptation_catalog_manifest_v1.json", {
        "schemaVersion": 1,
        "totalRecords": sum(int(x["records"]) for x in adaptation_catalogs),
        "catalogs": adaptation_catalogs,
    }, pretty=True)

    decoded_counts["recoveredAdaptationRecords"] = sum(int(x["records"]) for x in adaptation_catalogs)

    still_opaque_suffixes = ["vagmodelcodes_crypto.db", "vag.micro.vag", "vag.strings.vag"]
    opaque: list[dict[str, object]] = []
    for suffix in still_opaque_suffixes:
        matches = list(resources.glob(f"*{suffix}"))
        if not matches:
            continue
        source = matches[0]
        opaque.append({"name": source.name, "size": source.stat().st_size, "sha256": sha256(source), "state": "preserved-not-yet-normalized"})

    dll = assemblies / "CarScannerMaui.dll"
    anchors = [
        "LoadVAG_MQB",
        "LoadVAG_PQ26",
        "LoadVAG_PQ26_NewRapid2020",
        "LoadVAG_MLB_A4B9",
        "LoadVAG_MEB",
        "OpenFileCryptoStream2",
        "BinaryDeserializeFromEmbeddedFileUsingCompressedCryptoStream2",
        "BinaryDeserilzeFromEmbeddedFileUsingCryptoStream2",
        "BinaryDeserializeFromEmbeddedFileUsingCompressedCryptoStreamWithDiff",
        "ShiftStream",
        "ShiftStream2",
        "ShiftStream3",
        "Deserialize",
        "DeserializeFromStream",
        "MQBAdaptationTemplate",
        "ToMQBAdaptationTemplate",
        "ComputeKeyBytesFromSeed",
        "HutSecurityAccess",
    ]
    dll_strings = ascii_strings(dll)
    found = {anchor: any(anchor in value for value in dll_strings) for anchor in anchors}

    source_zip_hash = ""
    if args.source_zip and args.source_zip.exists():
        source_zip_hash = sha256(args.source_zip)

    write_json(out / "recovery_manifest_v1.json", {
        "schemaVersion": 1,
        "recoverySource": args.source_zip.name if args.source_zip else "legacy-recovery",
        "recoverySourceSha256": source_zip_hash,
        "assembly": {
            "name": dll.name,
            "size": dll.stat().st_size,
            "sha256": sha256(dll),
            "anchors": found,
        },
        "decoded": decoded_counts,
        "opaqueResources": opaque,
        "policy": {
            "runtimeLegacyDeserialization": False,
            "writesFromRecoveredOpaqueCatalogEnabled": False,
            "normalizedAdaptationCatalogEnabled": True,
            "note": "ShiftStream2+BSON adaptation databases are normalized offline. Runtime writes remain guarded; Security Access/custom procedures stay locked until separately verified.",
        },
    }, pretty=True)

    print(f"Recovered {len(dtc_records)} VAG DTC records")
    print(f"Recovered adaptation records: {sum(int(x['records']) for x in adaptation_catalogs)}")
    print(f"Still preserved-only resources: {len(opaque)}")
    print(f"Output: {out}")


if __name__ == "__main__":
    main()
