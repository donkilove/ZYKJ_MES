from __future__ import annotations

from dataclasses import dataclass


PARAMETER_TYPE_TEXT = "Text"
PARAMETER_TYPE_LINK = "Link"
ALLOWED_PARAMETER_TYPES = {PARAMETER_TYPE_TEXT, PARAMETER_TYPE_LINK}


@dataclass(frozen=True)
class ProductParameterTemplateItem:
    sort_order: int
    name: str
    category: str
    parameter_type: str


PRODUCT_PARAMETER_TEMPLATE: tuple[ProductParameterTemplateItem, ...] = (
    ProductParameterTemplateItem(1, "产品名称", "基础参数", PARAMETER_TYPE_TEXT),
    ProductParameterTemplateItem(2, "产品分类", "基础参数", PARAMETER_TYPE_TEXT),
    ProductParameterTemplateItem(3, "产品芯片", "基础参数", PARAMETER_TYPE_TEXT),
    ProductParameterTemplateItem(4, "产品功率", "基础参数", PARAMETER_TYPE_TEXT),
    ProductParameterTemplateItem(5, "产品信道", "基础参数", PARAMETER_TYPE_TEXT),
    ProductParameterTemplateItem(6, "作业指导书", "基础参数", PARAMETER_TYPE_LINK),
    ProductParameterTemplateItem(7, "激光打标导轨间距", "激光打标参数", PARAMETER_TYPE_TEXT),
    ProductParameterTemplateItem(8, "激光打标镜头高度", "激光打标参数", PARAMETER_TYPE_TEXT),
    ProductParameterTemplateItem(9, "激光打标文件位置", "激光打标参数", PARAMETER_TYPE_TEXT),
    ProductParameterTemplateItem(10, "产品测试项目", "产品测试参数", PARAMETER_TYPE_TEXT),
    ProductParameterTemplateItem(11, "程序烧录位号", "产品测试参数", PARAMETER_TYPE_TEXT),
    ProductParameterTemplateItem(12, "程序烧录软件", "产品测试参数", PARAMETER_TYPE_LINK),
    ProductParameterTemplateItem(13, "机台测试位号", "产品测试参数", PARAMETER_TYPE_TEXT),
    ProductParameterTemplateItem(14, "产品测试软件", "产品测试参数", PARAMETER_TYPE_LINK),
    ProductParameterTemplateItem(15, "产品组装物料", "产品组装参数", PARAMETER_TYPE_TEXT),
    ProductParameterTemplateItem(16, "产品组装工具", "产品组装参数", PARAMETER_TYPE_TEXT),
    ProductParameterTemplateItem(17, "产品包装方式", "产品包装参数", PARAMETER_TYPE_TEXT),
    ProductParameterTemplateItem(18, "产品包装配件", "产品包装参数", PARAMETER_TYPE_TEXT),
)

PRODUCT_PARAMETER_TEMPLATE_NAME_SET = {
    item.name for item in PRODUCT_PARAMETER_TEMPLATE
}

