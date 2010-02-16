<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        xmlns:exslt="http://exslt.org/common"
        exclude-result-prefixes="exslt"
>

<xsl:import href="convert14to20.xsl"/>
<xsl:import href="convert20to24.xsl"/>
<xsl:import href="convert24to35.xsl"/>
<xsl:import href="convert35to37.xsl"/>
<xsl:import href="convert37to38.xsl"/>
<xsl:import href="convert38to39.xsl"/>
<xsl:import href="convert39to41.xsl"/>
<xsl:import href="convert41to42.xsl"/>
<xsl:import href="convert42to43.xsl"/>
<xsl:import href="pretty.xsl"/>


<xsl:output encoding="utf-8"/>

<xsl:template match="/">
    <xsl:variable name="v14">
        <xsl:apply-templates select="/" mode="conv14to20"/>
    </xsl:variable>

    <xsl:variable name="v20">
        <xsl:apply-templates select="exslt:node-set($v14)" mode="conv20to24"/>
    </xsl:variable>

    <xsl:variable name="v35">
        <xsl:apply-templates select="exslt:node-set($v20)" mode="conv24to35"/>
    </xsl:variable>

    <xsl:variable name="v37">
        <xsl:apply-templates select="exslt:node-set($v35)" mode="conv35to37"/>
    </xsl:variable>

    <xsl:variable name="v38">
        <xsl:apply-templates select="exslt:node-set($v37)" mode="conv37to38"/>
    </xsl:variable>

    <xsl:variable name="v39">
        <xsl:apply-templates select="exslt:node-set($v38)" mode="conv38to39"/>
    </xsl:variable>

    <xsl:variable name="v41">
        <xsl:apply-templates select="exslt:node-set($v39)" mode="conv39to41"/>
    </xsl:variable>

    <xsl:variable name="v42">
        <xsl:apply-templates select="exslt:node-set($v41)" mode="conv41to42"/>
    </xsl:variable>

    <xsl:variable name="v43">
        <xsl:apply-templates select="exslt:node-set($v42)" mode="conv42to43"/>
    </xsl:variable>

    <xsl:apply-templates
        select="exslt:node-set($v43)" mode="pretty"
    />
</xsl:template>

</xsl:stylesheet>
