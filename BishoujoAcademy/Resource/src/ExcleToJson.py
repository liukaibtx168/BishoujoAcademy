import os
import pandas as pd
import json
from pathlib import Path

def convert_value(value, type_hint):
    """根据类型声明转换数据"""
    if pd.isna(value) or value in ["", "null"]:
        return {
            "int": 0,
            "int[]": [],
            "string": "",
            "json": {}
        }.get(type_hint, None)

    try:
        if type_hint == "int":
            return int(float(value)) if isinstance(value, str) and "." in value else int(value)
        elif type_hint == "int[]":
            if value:  # 检查是否有值
                parts = str(value).split(";")  # 按照';'切分
                # 确保返回格式为字典，带有 [1]， [2] 格式
                return {f"[{i + 1}]": int(float(x.strip())) for i, x in enumerate(parts) if x.strip()}
            else:
                return {}  # 如果没有值，返回空字典
        elif type_hint == "string":
            return str(value).strip()
        elif type_hint == "json":
            try:
                return json.loads(value)
            except:
                kvs = [x.strip() for x in str(value).split(",")]
                return {f"key{i+1}": v for i, v in enumerate(kvs)}
        else:
            return str(value)
    except Exception as e:
        print(f"转换失败: {value} ({type_hint}) - {str(e)}")
        return None

def process_excel(file_path, output_dir):
    """处理单个Excel文件"""
    try:
        config_df = pd.read_excel(file_path, header=None, nrows=4)

        valid_columns = 0
        for col in range(config_df.shape[1]):
            if pd.isna(config_df.iloc[1, col]) or pd.isna(config_df.iloc[2, col]):
                break
            valid_columns += 1
        
        fields = [config_df.iloc[1, col].strip() for col in range(valid_columns)]
        types = [config_df.iloc[2, col].lower().strip() for col in range(valid_columns)]
        
        # 从第4行开始读取数据，跳过前3行
        data_df = pd.read_excel(
            file_path,
            skiprows=2,  # 跳过前3行
            usecols=range(valid_columns),
            names=fields,
            dtype=str
        )

        result = {}
        for index, row in data_df.iterrows():
            entry = {}
            for field, type_hint in zip(fields, types):
                value = row[field] if field in row else None
                entry[field] = convert_value(value, type_hint)

            # 确保ID字段有效
            if "ID" in entry and entry["ID"] is not None:
                entry["ID"] = int(entry["ID"])  # 强制转换为整数
                result[entry["ID"]] = entry

        # 生成JSON
        output_path = Path(output_dir) / f"{Path(file_path).stem}.json"
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(result, f, ensure_ascii=False, indent=2)

        print(f"成功生成：{output_path}")

    except Exception as e:
        print(f"处理文件失败：{file_path}\n错误信息: {str(e)}")

def batch_convert(input_dir, output_dir):
    """批量处理目录下所有Excel"""
    input_dir = Path(input_dir)
    output_dir = Path(output_dir)
    output_dir.mkdir(exist_ok=True)
    
    for excel_file in input_dir.glob("*.xlsx"):
        process_excel(excel_file, output_dir)

if __name__ == "__main__":
    # 使用相对路径
    script_dir = Path(__file__).parent
    input_path = script_dir / "excle"
    output_path = script_dir / "json"
    
    batch_convert(input_path, output_path)
    print("批处理完成！")