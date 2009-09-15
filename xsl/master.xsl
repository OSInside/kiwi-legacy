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

	<xsl:apply-templates
        select="exslt:node-set($v35)" mode="conv35to37"
    />
</xsl:template>

</xsl:stylesheet>
