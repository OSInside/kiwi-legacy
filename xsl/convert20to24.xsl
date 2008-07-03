<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:include href="/usr/share/kiwi/xsl/convert14to20.xsl"/>


<xsl:output method="xml" indent="yes" omit-xml-declaration="no"/>
<xsl:strip-space elements="type"/>

<xsl:template match="*|processing-instruction()|comment()" mode="conv20to24">
	<xsl:copy>
		<xsl:copy-of select="@*"/>
		<xsl:apply-templates mode="conv20to24"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="/">
	<xsl:choose>
		<xsl:when test="image[@schemeversion='2.0']">
			<xsl:apply-templates mode="conv20to24"/>
		</xsl:when>
		<xsl:when test="image[@schemeversion='2.4']">
			<xsl:message terminate="yes">
				<xsl:text>Already at version 2.4... skipped</xsl:text>
			</xsl:message>
		</xsl:when>
		<xsl:otherwise>
			<xsl:message terminate="yes">
				<xsl:text>ERROR: Schema version is not correct.&#10;</xsl:text>
				<xsl:text>       I got '</xsl:text>
				<xsl:value-of select="image/@schemeversion"/>
				<xsl:text>', but expected version 2.0.</xsl:text>
			</xsl:message>
		</xsl:otherwise>
	</xsl:choose>  
</xsl:template>

<para xmlns="http://docbook.org/ns/docbook">
	Changed attribute <tag class="attribute">schemeversion</tag>
	from <literal>2.0</literal> to <literal>2.4</literal>. 
</para>
<xsl:template match="image" mode="conv20to24">
	<image schemeversion="2.4">
		<xsl:copy-of select="@name"/>
		<xsl:apply-templates mode="conv20to24"/>
	</image>
</xsl:template>

<para xmlns="http://docbook.org/ns/docbook">
	Remove attributes memory,disk,HWversion,guestOS_32Bit and guestOS_64Bit
	from the <literal>2.0</literal> packages type [vmware|xen] version.
	This information needs to be provided by an additional
	<tag class="element">vmwareconfig</tag> or
	<tag class="element">xenconfig</tag> element
</para>
<xsl:template match="packages[@type='vmware']" mode="conv20to24">
	<xsl:message>
		<xsl:text>NOTE: You need to setup a vmwareconfig section&#10;</xsl:text>
		<xsl:text>      Details in the 'KIWI image description'&#10;</xsl:text>
		<xsl:text>      chapter of the kiwi cookbook</xsl:text>
    </xsl:message>
	<xsl:copy>
		<xsl:copy-of select="@*[name() = 'type']"/>
		<xsl:copy-of select="@*[name() = 'profiles']"/>
		<xsl:copy-of select="@*[name() = 'patternType']"/>
		<xsl:copy-of select="@*[name() = 'patternPackageType']"/>
		<xsl:apply-templates mode="conv20to24"/>
	</xsl:copy>
</xsl:template>
<xsl:template match="packages[@type='xen']" mode="conv20to24">
	<xsl:message>
		<xsl:text>NOTE: You need to setup a xenconfig section&#10;</xsl:text>
		<xsl:text>      Details in the 'KIWI image description'&#10;</xsl:text>
		<xsl:text>      chapter of the kiwi cookbook</xsl:text>
	</xsl:message>
	<xsl:copy>
		<xsl:copy-of select="@*[name() = 'type']"/>
		<xsl:copy-of select="@*[name() = 'profiles']"/>
		<xsl:copy-of select="@*[name() = 'patternType']"/>
		<xsl:copy-of select="@*[name() = 'patternPackageType']"/>
		<xsl:apply-templates mode="conv20to24"/>
	</xsl:copy>
</xsl:template>

</xsl:stylesheet>
